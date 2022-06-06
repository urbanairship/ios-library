/* Copyright Airship and Contributors */

import Foundation

/// Airship permissions. Used with `PermissionsManager`
@objc(UAPermission)
public enum Permission: UInt, CustomStringConvertible {
    /// Post notifications
    case postNotifications

    /// Location
    case location

    /// Bluetooth
    case bluetooth

    /// App transparency tracking
    case appTransparencyTracking

    /// Microphone access
    case mic

    /// Media on device
    case media

    /// Camera
    case camera

    /// Contacts
    case contacts


    /// The string value of the permission
    /// - Returns: The string value of the permission
    var stringValue: String {
        switch self {
        case .postNotifications: return "post_notifications"
        case .location: return "location"
        case .bluetooth: return "bluetooth"
        case .mic: return "mic"
        case .media: return "media"
        case .camera: return "camera"
        case .appTransparencyTracking: return "app_transparency_tracking"
        case .contacts: return "contacts"
        }
    }

    /// Returns a permission from a string.
    /// - Parameter value: The string value
    /// - Returns: A permission.
    static func fromString(_ value: String) throws -> Permission {
        switch (value.lowercased()) {
        case "post_notifications": return .postNotifications
        case "location": return .location
        case "bluetooth": return .bluetooth
        case "mic": return .mic
        case "media": return .media
        case "camera": return .camera
        case "contacts": return .contacts
        case "app_transparency_tracking": return .appTransparencyTracking
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
