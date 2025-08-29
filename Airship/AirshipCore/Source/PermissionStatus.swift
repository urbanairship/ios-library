/* Copyright Airship and Contributors */

import Foundation

/// Permission status
public enum AirshipPermissionStatus: String, Sendable, Codable {
    /// Could not determine the permission status.
    case notDetermined = "not_determined"

    /// Permission is granted.
    case granted

    /// Permission is denied.
    case denied
}
