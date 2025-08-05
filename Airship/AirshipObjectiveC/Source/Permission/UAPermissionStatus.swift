/* Copyright Airship and Contributors */

public import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Permission status
@objc
public enum UAPermissionStatus: Int, Sendable {
    /// Could not determine the permission status.
    case notDetermined = 0

    /// Permission is granted.
    case granted = 1

    /// Permission is denied.
    case denied = 2

    internal init(from status: AirshipPermissionStatus) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .granted:
            self = .granted
        case .denied:
            self = .denied
        @unknown default:
            self = .notDetermined
        }
    }

    internal var airshipStatus: AirshipPermissionStatus {
        switch self {
        case .notDetermined:
            return .notDetermined
        case .granted:
            return .granted
        case .denied:
            return .denied
        }
    }
}
