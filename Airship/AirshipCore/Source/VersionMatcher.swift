// Copyright Airship and Contributors

import Foundation


/// Version matcher.
@available(*, deprecated, message: "Marked to be removed in SDK 20")
public class VersionMatcher: NSObject {

    private let ivyVersionMatcher: IvyVersionMatcher

    /// NOTE: For internal use only. :nodoc:
    public init?(versionConstraint: String) {
        guard let versionMatcher = try? IvyVersionMatcher(versionConstraint: versionConstraint) else {
            return nil
        }
        self.ivyVersionMatcher = versionMatcher
    }

    /**
     * Create a matcher for the supplied version constraint
     *
     * - Parameters:
     *   - versionConstraint: constraint that matches one of our supported patterns
     * - Returns: matcher or nil if versionConstraint does not match any of the expected patterns
     */
    public class func matcher(versionConstraint: String) -> VersionMatcher? {
        return VersionMatcher(versionConstraint: versionConstraint)
    }

    /**
     * Evaluates the object with the matcher.
     *
     * - Parameters:
     *   - value: The object to evaluate.
     * - Returns: true if the matcher matches the object, otherwise false.
     */
    public func evaluate(_ value: Any?) -> Bool {
        guard let version = value as? String else {
            return false
        }

        return self.ivyVersionMatcher.evaluate(version: version)
    }
}

