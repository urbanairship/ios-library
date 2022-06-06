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


    /// The string value of the status
    /// - Returns: The string value of the status
    var stringValue: String {
        switch self {
        case .notDetermined: return "not_determined"
        case .granted: return "granted"
        case .denied: return "denied"
        }
    }
}
