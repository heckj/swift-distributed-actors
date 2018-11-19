//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Actors open source project
//
// Copyright (c) 2018-2019 Apple Inc. and the Swift Distributed Actors project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.md for the list of Swift Distributed Actors project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import CQueue
import NIOConcurrencyHelpers
import Foundation // TODO remove

/// INTERNAL API
struct Envelope<Message> {
  let payload: Message

  // Note that we can pass around senders however we can not automatically get the type of them right.
  // We may want to carry around the sender path for debugging purposes though "[pathA] crashed because message [Y] from [pathZ]"
  // TODO explain this more
  #if SACTANA_DEBUG
  let senderPath: ActorPath
  #endif

  // Implementation notes:
  // Envelopes are also used to enable tracing, both within an local actor system as well as across systems
  // the beauty here is that we basically have the "right place" to put the trace metadata - the envelope
  // and don't need to do any magic around it
}

/// Wraps context for use in closures passed to C
private struct WrappedClosure {
  private let _exec: (UnsafeMutableRawPointer) throws -> Bool
  private let _fail: (Error) -> ()

  init(exec: @escaping (UnsafeMutableRawPointer) throws -> Bool,
       fail: @escaping (Error) -> ()) {
    self._exec = exec
    self._fail = fail
  }

  @inlinable
  func exec(with ptr: UnsafeMutableRawPointer) throws -> Bool {
    return try _exec(ptr)
  }

  @inlinable
  func fail(error: Error) -> Bool {
    _fail(error) // mutates ActorCell to become failed
    return false // TODO cell to decide if to continue later on (supervision)
  }
}

// TODO: we may have to make public to enable inlining? :-( https://github.com/apple/swift-distributed-actors/issues/69
final class Mailbox<Message> {
  private var mailbox: UnsafeMutablePointer<CMailbox>
  private var cell: ActorCell<Message>

  // Implementation note: WrappedClosures are used for C-interop
  private var messageCallbackContext: WrappedClosure
  private var systemMessageCallbackContext: WrappedClosure

  private let interpretMessage: InterpretMessageCallback

  init(cell: ActorCell<Message>, capacity: Int, maxRunLength: Int = 100) {
    self.mailbox = cmailbox_create(Int64(capacity), Int64(maxRunLength));
    self.cell = cell

    self.messageCallbackContext = WrappedClosure(exec: { ptr in
      let envelopePtr = ptr.assumingMemoryBound(to: Envelope<Message>.self)
      let envelope = envelopePtr.move()
      let msg = envelope.payload
      return cell.interpretMessage(message: msg)
    }, fail: { error in
      cell.fail(error: error)
    })

    self.systemMessageCallbackContext = WrappedClosure(exec: { ptr in
      let envelopePtr = ptr.assumingMemoryBound(to: SystemMessage.self)
      let msg = envelopePtr.move()
      return try cell.interpretSystemMessage(message: msg)
    }, fail: { error in
      cell.fail(error: error)
    })

    self.interpretMessage = { (ctxPtr, msg) in
      defer { msg?.deallocate() }
      let ctx = ctxPtr?.assumingMemoryBound(to: WrappedClosure.self)
      // FIXME the try! is harsh here... we want to allow our users to throw in actor code I think

      var shouldContinue: Bool
      do {
        shouldContinue = try ctx?.pointee.exec(with: msg!) ?? false // FIXME don't like the many ? around here hm, likely costs -- ktoso
      } catch {
        #if SACT_TRACE_MAILBOX
        pprint("Error while processing message! Was: \(error) TODO supervision decisions...")
        #endif

        // TODO supervision can decide to stop... we now stop always though
        shouldContinue = ctx?.pointee.fail(error: error) ?? false // TODO supervision could be looped in here somehow...? fail returns the behavior to interpret etc, 2nd failure is a hard crash tho perhaps -- ktoso
      }

      return shouldContinue
    }
  }

  deinit {
    cmailbox_destroy(mailbox)
  }

  @inlinable
  func sendMessage(envelope: Envelope<Message>) -> Void {
    let ptr = UnsafeMutablePointer<Envelope<Message>>.allocate(capacity: 1)
    ptr.initialize(to: envelope)
    if (cmailbox_send_message(mailbox, ptr)) {
      cell.dispatcher.execute(self.run)
    }
  }

  @inlinable
  func sendSystemMessage(_ systemMessage: SystemMessage) -> Void {
    let ptr = UnsafeMutablePointer<SystemMessage>.allocate(capacity: 1)
    ptr.initialize(to: systemMessage)
    if  cmailbox_send_system_message(mailbox, ptr) {
      cell.dispatcher.execute(self.run)
    }
  }

  @inlinable
  func run() -> Void {
    let shouldReschedule: Bool = cmailbox_run(mailbox, &messageCallbackContext, &systemMessageCallbackContext, interpretMessage)

    if shouldReschedule {
      cell.dispatcher.execute(self.run)
    }
  }
}
