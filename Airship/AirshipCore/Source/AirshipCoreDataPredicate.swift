/* Copyright Airship and Contributors */

public import Foundation

/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public struct AirshipCoreDataPredicate: Sendable {
    private let format: String
    private let args: [any Sendable]?
    
    public init(format: String, args: [any Sendable]? = nil) {
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
