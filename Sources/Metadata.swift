//
//  Metadata.swift
//  Impeller
//
//  Created by Drew McCormack on 08/12/2016.
//  Copyright © 2016 Drew McCormack. All rights reserved.
//

import Foundation

public typealias UniqueIdentifier = String

/// Metadata for a repositable
public struct Metadata: Equatable {

    public enum Key: String {
        case uniqueIdentifier, commitIdentifier, isDeleted, timestampsByPropertyName
    }

    public let uniqueIdentifier: UniqueIdentifier
    public var timestampsByPropertyName = [String:TimeInterval]()

    internal var ancestry: [ValueTreeIdentity]?        // Should only be nil before being committed first time
    internal var commitIdentifier: CommitIdentifier?   // nil if not committed yet
    internal var headWhenFetched: CommitIdentifier?    // nil if not attached to a fetched value
    internal var isDeleted: Bool

    public init(uniqueIdentifier: UniqueIdentifier = UUID().uuidString) {
        self.uniqueIdentifier = uniqueIdentifier
        self.isDeleted = false
    }

    public static func == (left: Metadata, right: Metadata) -> Bool {
        return left.uniqueIdentifier == right.uniqueIdentifier && left.commitIdentifier == right.commitIdentifier && left.isDeleted == right.isDeleted && left.timestampsByPropertyName == right.timestampsByPropertyName && left.headWhenFetched == right.headWhenFetched
    }

}
