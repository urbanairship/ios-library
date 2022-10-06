import Foundation

@objc(UAirshipWorkRequest)
public class AirshipWorkRequest: NSObject {

    @objc
    public let workID: String

    @objc
    public enum ConflictPolicy: Int {
        @objc(UAirshipWorkRequestConflictPolicyAppend)
        case append
        @objc(UAirshipWorkRequestConflictPolicyReplace)
        case replace
        @objc(UAirshipWorkRequestConflictPolicyKeep)
        case keep
    }

    @objc
    public let extras: [String: Any]?

    @objc
    public let initialDelay: TimeInterval

    @objc
    public let requiresNetwork: Bool

    @objc
    public let rateLimitIDs: [String]

    @objc
    public let conflictPolicy: ConflictPolicy

    @objc
    public init(
        workID: String,
        extras: [String: Any]? = nil,
        initialDelay: TimeInterval = 0.0,
        requiresNetwork: Bool = true,
        rateLimitIDs: [String] = [],
        conflictPolicy: ConflictPolicy = .replace
    ) {
        self.workID = workID
        self.extras = extras
        self.initialDelay = initialDelay
        self.requiresNetwork = requiresNetwork
        self.rateLimitIDs = rateLimitIDs
        self.conflictPolicy = conflictPolicy
    }
}
