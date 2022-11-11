/* Copyright Airship and Contributors */

/// - Note: For internal use only. :nodoc:
@objc(UATaskRequestOptions)
public class TaskRequestOptions: NSObject {
    @objc
    public let conflictPolicy: AirshipWorkRequest.ConflictPolicy

    @objc
    public let isNetworkRequired: Bool

    @objc
    public let extras: [String: Any]

    @objc
    public static let defaultOptions = TaskRequestOptions(
        conflictPolicy: .replace,
        requiresNetwork: true
    )

    @objc
    public init(
        conflictPolicy: AirshipWorkRequest.ConflictPolicy = .replace,
        requiresNetwork: Bool = false,
        extras: [String: Any]? = nil
    ) {
        self.conflictPolicy = conflictPolicy
        self.isNetworkRequired = requiresNetwork
        self.extras = extras ?? [:]
        super.init()
    }

    func isEqual(to options: TaskRequestOptions) -> Bool {
        return conflictPolicy == options.conflictPolicy
            && isNetworkRequired == options.isNetworkRequired
            && NSDictionary(dictionary: extras).isEqual(to: options.extras)
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let options = object as? TaskRequestOptions else {
            return false
        }

        if self === options {
            return true
        }

        return isEqual(to: options)
    }

    func hash() -> Int {
        var result = 1
        result = 31 * result + NSDictionary(dictionary: extras).hash
        result = 31 * result + conflictPolicy.rawValue
        result = 31 * result + (self.isNetworkRequired ? 1 : 0)
        return result
    }
}
