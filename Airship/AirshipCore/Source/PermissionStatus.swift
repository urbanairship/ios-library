/* Copyright Airship and Contributors */

import Foundation

/// Permission status
@objc(UAPermissionStatus)
public enum PermissionStatus: UInt {
    /// Could not determine the permission status.
    case notDetermined

    /// Permission is granted.
    case granted

    /// Permission is denied.
    case denied
}
