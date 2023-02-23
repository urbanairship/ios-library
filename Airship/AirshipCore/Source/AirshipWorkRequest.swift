/* Copyright Airship and Contributors */

import Foundation

@objc
public enum AirshipWorkRequestConflictPolicy: Int, Sendable {
    @objc(UAirshipWorkRequestConflictPolicyAppend)
    case append
    @objc(UAirshipWorkRequestConflictPolicyReplace)
    case replace
    @objc(UAirshipWorkRequestConflictPolicyKeep)
    case keep
}

public struct AirshipWorkRequest: Equatable, Sendable {

    public let workID: String
    public let extras: [String: String]?
    public let initialDelay: TimeInterval
    public let requiresNetwork: Bool
    public let rateLimitIDs: [String]
    public let conflictPolicy: AirshipWorkRequestConflictPolicy

    public init(
        workID: String,
        extras: [String: String]? = nil,
        initialDelay: TimeInterval = 0.0,
        requiresNetwork: Bool = true,
        rateLimitIDs: [String] = [],
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
