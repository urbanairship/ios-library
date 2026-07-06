/* Copyright Airship and Contributors */

public import Foundation

/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public enum AirshipWorkRequestConflictPolicy: Sendable {
    case append
    case replace
    case keepIfNotStarted
}

/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
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
