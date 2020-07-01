// ==== ------------------------------------------------------------------ ====
// === DO NOT EDIT: Generated by GenActors                     
// ==== ------------------------------------------------------------------ ====

//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Actors open source project
//
// Copyright (c) 2019 Apple Inc. and the Swift Distributed Actors project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.md for the list of Swift Distributed Actors project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import ActorSingletonPlugin
@testable import DistributedActors
import DistributedActorsTestKit
import XCTest

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: DO NOT EDIT: Codable conformance for GreeterSingleton.Message
// TODO: This will not be required, once Swift synthesizes Codable conformances for enums with associated values 

extension GreeterSingleton.Message {
    // TODO: Check with Swift team which style of discriminator to aim for
    public enum DiscriminatorKeys: String, Decodable {
        case greet

    }

    public enum CodingKeys: CodingKey {
        case _case
        case greet_name
        case greet__replyTo

    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(DiscriminatorKeys.self, forKey: CodingKeys._case) {
        case .greet:
            let name = try container.decode(String.self, forKey: CodingKeys.greet_name)
            let _replyTo = try container.decode(ActorRef<String>.self, forKey: CodingKeys.greet__replyTo)
            self = .greet(name: name, _replyTo: _replyTo)

        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .greet(let name, let _replyTo):
            try container.encode(DiscriminatorKeys.greet.rawValue, forKey: CodingKeys._case)
            try container.encode(name, forKey: CodingKeys.greet_name)
            try container.encode(_replyTo, forKey: CodingKeys.greet__replyTo)

        }
    }
}
