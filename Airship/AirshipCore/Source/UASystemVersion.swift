// Copyright Airship and Contributors

import Foundation

/**
 * @note For internal use only. :nodoc:
 */
@objc
open class UASystemVersion : NSObject {

    @objc
    open var currentSystemVersion : String {
        get {
            return UIDevice.current.systemVersion
        }
    }

    @objc
    public func isGreaterOrEqual(_ version: String) -> Bool {
        let systemVersion = currentSystemVersion
        let result: ComparisonResult? = systemVersion.compare(version, options: .numeric, range: nil, locale: .current)
        return result == .orderedSame || result == .orderedDescending
    }
}
