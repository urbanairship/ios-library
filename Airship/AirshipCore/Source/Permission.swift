/* Copyright Airship and Contributors */

import Foundation

/// Airship permissions. Used with `PermissionsManager`
public enum AirshipPermission: String, Sendable, Codable {
    /// Post notifications
    case displayNotifications = "display_notifications"

    /// Location
    case location

    /// App Tracking Transparency
    case appTrackingTransparency = "app_tracking_transparency"

    /// Camera
    case camera

    /// Microphone
    case microphone

    /// Bluetooth
    case bluetooth

    /// Photo library
    case photoLibrary = "photo_library"

    /// Contacts
    case contacts
}
