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

import ClusterMembership
import enum Dispatch.DispatchTimeInterval
import SWIM

extension SWIM {
    public typealias PeerRef = ActorRef<SWIM.Message>

    public typealias Ref = ActorRef<SWIM.Message>
    public typealias PingOriginRef = ActorRef<SWIM.Message> // same type, but actually an `ask` actor
    public typealias PingRequestOriginRef = ActorRef<SWIM.Message> // same type, but actually an `ask` actor

    typealias Shell = SWIMActorShell
}

public protocol AnySWIMMessage {}

extension SWIM.Message: AnySWIMMessage {}

extension SWIM.PingResponse: AnySWIMMessage {}

/// :nodoc:
extension ActorRef: SWIMAddressablePeer where Message: AnySWIMMessage {
    public var node: ClusterMembership.Node {
        .init(protocol: self.address.uniqueNode.node.protocol, host: self.address.uniqueNode.host, port: self.address.uniqueNode.port, uid: self.address.uniqueNode.nid.value)
    }
}

extension SWIMPeer {
    public func ping(
        payload: SWIM.GossipPayload,
        timeout: DispatchTimeInterval,
        sequenceNumber: SWIM.SequenceNumber,
        context: ActorContext<SWIM.Message>,
        onResponse: @escaping (Result<SWIM.PingResponse, Error>) -> Void
    ) {
        guard let ref = self as? SWIM.Ref else {
            onResponse(.failure(IllegalSWIMPeerTypeError("Expected self to ge \(SWIM.Ref.self) but was: \(self)")))
            return
        }

        let promise = context.system._eventLoopGroup.next().makePromise(of: SWIM.PingResponse.self)

        ref.ask(for: SWIM.Message.self, timeout: .nanoseconds(timeout.nanoseconds)) { replyTo in
            SWIM.Message.remote(.ping(pingOrigin: replyTo, payload: payload, sequenceNumber: sequenceNumber))
        }._onComplete { (result: Result<SWIM.Message, Error>) in
            switch result {
            case .success(.remote(.pingResponse(let response))):
                switch response {
                case .ack, .timeout:
                    promise.succeed(response)
                case .nack:
                    promise.fail(IllegalSWIMMessageTypeError("Unexpected .nack reply to .ping message! Was: \(response)"))
                }
            case .success(let message):
                promise.fail(IllegalSWIMMessageTypeError("Expected .ack, but received unexpected reply to .ping: \(message)"))
            case .failure(let error):
                promise.fail(error)
            }
        }

        context.onResultAsync(of: promise.futureResult, timeout: .effectivelyInfinite) { result in
            onResponse(result)
            return .same
        }
    }

    public func pingRequest(
        target: SWIMPeer,
        payload: SWIM.GossipPayload,
        timeout: DispatchTimeInterval,
        sequenceNumber: SWIM.SequenceNumber,
        context: ActorContext<SWIM.Message>,
        onResponse: @escaping (Result<SWIM.PingResponse, Error>) -> Void
    ) {
        guard let ref = self as? SWIM.Ref else {
            onResponse(.failure(IllegalSWIMPeerTypeError("Expected self to ge \(SWIM.Ref.self) but was: \(self)")))
            return
        }

        guard let targetRef = target as? SWIM.Ref else {
            onResponse(.failure(IllegalSWIMPeerTypeError("Expected target to ge \(SWIM.Ref.self) but was: \(target)")))
            return
        }

        let promise = context.system._eventLoopGroup.next().makePromise(of: SWIM.PingResponse.self)

        ref.ask(for: SWIM.PingRequestOriginRef.Message.self, timeout: .nanoseconds(timeout.nanoseconds)) { replyTo in
            SWIM.Message.remote(.pingRequest(target: targetRef, pingRequestOrigin: replyTo, payload: payload, sequenceNumber: sequenceNumber))
        }._onComplete { (result: Result<SWIM.Message, Error>) in
            switch result {
            case .success(.remote(.pingResponse(let response))):
                promise.succeed(response)
            case .success(let message):
                promise.fail(IllegalSWIMMessageTypeError("Expected .ack, but received unexpected reply to .ping: \(message)"))
            case .failure(let error):
                promise.fail(error)
            }
        }

        context.onResultAsync(of: promise.futureResult, timeout: .effectivelyInfinite) { result in
            onResponse(result)
            return .same
        }
    }
}

/// :nodoc:
extension ActorRef: SWIMPeer where Message == SWIM.Message {
    // Implementation note: origin is ignored on purpose, and that's okay since we perform the question via an `ask`
    public func ping(
        payload: SWIM.GossipPayload,
        from _: SWIMPingOriginPeer,
        timeout: DispatchTimeInterval,
        sequenceNumber: SWIM.SequenceNumber,
        onResponse: @escaping (Result<SWIM.PingResponse, Error>) -> Void
    ) {
        self.ask(for: SWIM.Message.self, timeout: .nanoseconds(timeout.nanoseconds)) { replyTo in
            SWIM.Message.remote(.ping(pingOrigin: replyTo, payload: payload, sequenceNumber: sequenceNumber))
        }._onComplete { (result: Result<SWIM.Message, Error>) in
            switch result {
            case .success(.remote(.pingResponse(let response))):
                switch response {
                case .ack, .timeout:
                    onResponse(.success(response))
                case .nack:
                    onResponse(.failure(IllegalSWIMMessageTypeError("Unexpected .nack reply to .ping message! Was: \(response)")))
                }
            case .success(let message):
                onResponse(.failure(IllegalSWIMMessageTypeError("Expected .ack, but received unexpected reply to .ping: \(message)")))
            case .failure(let error):
                onResponse(.failure(error))
            }
        }
    }

    // Implementation note: origin is ignored on purpose, and that's okay since we perform the question via an `ask`
    public func pingRequest(
        target: SWIMPeer,
        payload: SWIM.GossipPayload,
        from _: SWIMPingRequestOriginPeer,
        timeout: DispatchTimeInterval,
        sequenceNumber: SWIM.SequenceNumber,
        onResponse: @escaping (Result<SWIM.PingResponse, Error>) -> Void
    ) {
        guard let targetRef = target as? SWIM.Ref else {
            onResponse(.failure(IllegalSWIMPeerTypeError("Expected target to ge \(SWIM.Ref.self) but was: \(target)")))
            return
        }

        self.ask(for: SWIM.PingRequestOriginRef.Message.self, timeout: .nanoseconds(timeout.nanoseconds)) { replyTo in
            SWIM.Message.remote(.pingRequest(target: targetRef, pingRequestOrigin: replyTo, payload: payload, sequenceNumber: sequenceNumber))
        }._onComplete { (result: Result<SWIM.Message, Error>) in
            switch result {
            case .success(.remote(.pingResponse(let response))):
                onResponse(.success(response))
            case .success(let message):
                onResponse(.failure(IllegalSWIMMessageTypeError("Expected .ack, but received unexpected reply to .ping: \(message)")))
            case .failure(let error):
                onResponse(.failure(error))
            }
        }
    }
}

///// :nodoc:
// extension ActorRef: SWIMPingOriginPeer where Message == SWIM.PingResponse {
//    public func ack(
//        acknowledging sequenceNumber: SWIM.SequenceNumber,
//        target: SWIMPeer,
//        incarnation: SWIM.Incarnation,
//        payload: SWIM.GossipPayload
//    ) {
//        guard let targetRef = target as? SWIM.Ref else {
//            let error = IllegalSWIMPeerTypeError("Expected target to ge \(SWIM.Ref.self) but was: \(target)")
//            fatalError("\(error)")
//        }
//
//         self.tell(.ack(target: targetRef, incarnation: incarnation, payload: payload, sequenceNumber: sequenceNumber))
//    }
// }
//
///// :nodoc:
// extension ActorRef: SWIMPingRequestOriginPeer where Message == SWIM.PingResponse {
//    public func nack(
//        acknowledging sequenceNumber: SWIM.SequenceNumber,
//        target: SWIMPeer
//    ) {
//        guard let targetRef = target as? SWIM.Ref else {
//            let error = IllegalSWIMPeerTypeError("Expected target to ge \(SWIM.Ref.self) but was: \(target)")
//            fatalError("\(error)")
//        }
//
//         self.tell(.nack(target: target, sequenceNumber: sequenceNumber))
//    }
// }

/// :nodoc:
extension ActorRef: SWIMPingOriginPeer where Message == SWIM.Message {
    public func ack(
        acknowledging sequenceNumber: SWIM.SequenceNumber,
        target: SWIMPeer,
        incarnation: SWIM.Incarnation,
        payload: SWIM.GossipPayload
    ) {
        self.tell(.remote(.pingResponse(.ack(target: target, incarnation: incarnation, payload: payload, sequenceNumber: sequenceNumber))))
    }
}

/// :nodoc:
extension ActorRef: SWIMPingRequestOriginPeer where Message == SWIM.Message {
    public func nack(
        acknowledging sequenceNumber: SWIM.SequenceNumber,
        target: SWIMPeer
    ) {
        self.tell(.remote(.pingResponse(.nack(target: target, sequenceNumber: sequenceNumber))))
    }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Errors

internal struct IllegalSWIMPeerTypeError: Error {
    let message: String

    init(_ message: String) {
        self.message = message
    }
}

internal struct IllegalSWIMMessageTypeError: Error {
    let message: String

    init(_ message: String) {
        self.message = message
    }
}
