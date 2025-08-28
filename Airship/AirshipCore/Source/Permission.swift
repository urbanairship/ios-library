/* Copyright Airship and Contributors */



/// Airship permissions. Used with `PermissionsManager`
public enum AirshipPermission: String, Sendable, Codable {
    /// Post notifications
    case displayNotifications = "display_notifications"

    /// Location
    case location
}
