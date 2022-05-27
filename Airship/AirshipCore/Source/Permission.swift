/* Copyright Airship and Contributors */

import Foundation

/// Airship permissions. Used with `PermissionsManager`
@objc(UAPermission)
public enum Permission: UInt {
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
}
