/* Copyright Airship and Contributors */

import Foundation

/// - Note: for internal use only.  :nodoc:
public struct AirshipCoreDataPredicate: Sendable {
    private let format: String
    private let args: [Sendable]?
    
    public init(format: String, args: [Sendable]? = nil) {
        self.format = format
        self.args = args
    }
    
    public func toNSPredicate() -> NSPredicate {
        guard let args = args else {
            return NSPredicate(format: format)
        }
        return NSPredicate(format: format, argumentArray: args)
    }
}
