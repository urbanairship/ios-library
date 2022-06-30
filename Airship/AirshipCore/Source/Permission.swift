/* Copyright Airship and Contributors */

import Foundation

/// Airship permissions. Used with `PermissionsManager`
@objc(UAPermission)
public enum Permission: UInt, CustomStringConvertible {
    /// Post notifications
    case displayNotifications

    /// Location
    case location

    /// The string value of the permission
    /// - Returns: The string value of the permission
    var stringValue: String {
        switch self {
        case .displayNotifications: return "display_notifications"
        case .location: return "location"
        }
    }

    /// Returns a permission from a string.
    /// - Parameter value: The string value
    /// - Returns: A permission.
    static func fromString(_ value: String) throws -> Permission {
        switch (value.lowercased()) {
        case "display_notifications": return .displayNotifications
        case "location": return .location
        default: throw AirshipErrors.error("invalid permission \(value)")
        }
    }

    public var description: String {
        return stringValue
    }
}


extension Permission: Decodable {

    public init(from decoder: Decoder) throws {
        let singleValueContainer = try decoder.singleValueContainer()
        let string = try? singleValueContainer.decode(String.self)
        self = try Permission.fromString(string ?? "")
    }
}
