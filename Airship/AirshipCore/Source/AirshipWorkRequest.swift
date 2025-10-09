/* Copyright Airship and Contributors */

import Foundation

/// NOTE: For internal use only. :nodoc:
public enum AirshipWorkRequestConflictPolicy: Sendable {
    case append
    case replace
    case keepIfNotStarted
}


/// NOTE: For internal use only. :nodoc:
public struct AirshipWorkRequest: Equatable, Sendable, Hashable {
    public let workID: String
    public let extras: [String: String]?
    public let initialDelay: TimeInterval
    public let requiresNetwork: Bool
    public let rateLimitIDs: Set<String>?
    public let conflictPolicy: AirshipWorkRequestConflictPolicy

    public init(
        workID: String,
        extras: [String: String]? = nil,
        initialDelay: TimeInterval = 0.0,
        requiresNetwork: Bool = true,
        rateLimitIDs: Set<String>? = nil,
        conflictPolicy: AirshipWorkRequestConflictPolicy = .replace
    ) {
        self.workID = workID
        self.extras = extras
        self.initialDelay = initialDelay
        self.requiresNetwork = requiresNetwork
        self.rateLimitIDs = rateLimitIDs
        self.conflictPolicy = conflictPolicy
    }
}
