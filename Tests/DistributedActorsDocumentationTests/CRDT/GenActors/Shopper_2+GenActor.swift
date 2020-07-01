// ==== ------------------------------------------------------------------ ====
// === DO NOT EDIT: Generated by GenActors                     
// ==== ------------------------------------------------------------------ ====

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

// tag::imports[]

import DistributedActors
import Foundation

// end::imports[]

import DistributedActorsTestKit
import XCTest

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: DO NOT EDIT: Generated Shopper_2 messages 

/// DO NOT EDIT: Generated Shopper_2 messages
extension Shopper_2 {

    public enum Message: ActorMessage { 
        case add(item: String) 
        case checkOff(item: String) 
    }
    
}
// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: DO NOT EDIT: Generated Shopper_2 behavior

extension Shopper_2 {

    public static func makeBehavior(instance: Shopper_2) -> Behavior<Message> {
        return .setup { _context in
            let context = Actor<Shopper_2>.Context(underlying: _context)
            let instance = instance

            instance.preStart(context: context)

            return Behavior<Message>.receiveMessage { message in
                switch message { 
                
                case .add(let item):
                                        instance.add(item: item)

                     
                case .checkOff(let item):
                                        instance.checkOff(item: item)

                     
                
                }
                return .same
            }.receiveSignal { _context, signal in 
                let context = Actor<Shopper_2>.Context(underlying: _context)

                switch signal {
                case is Signals.PostStop: 
                    instance.postStop(context: context)
                    return .same
                case let terminated as Signals.Terminated:
                    switch try instance.receiveTerminated(context: context, terminated: terminated) {
                    case .unhandled: 
                        return .unhandled
                    case .stop: 
                        return .stop
                    case .ignore: 
                        return .same
                    }
                default:
                    try instance.receiveSignal(context: context, signal: signal)
                    return .same
                }
            }
        }
    }
}
// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Extend Actor for Shopper_2

extension Actor where Act.Message == Shopper_2.Message {

     func add(item: String) {
        self.ref.tell(Self.Message.add(item: item))
    }
 

     func checkOff(item: String) {
        self.ref.tell(Self.Message.checkOff(item: item))
    }
 

}
