/* Copyright Airship and Contributors */

public import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Airship permissions
@objc
public enum UAPermission: Int, Sendable {
    /// Post notifications
    case displayNotifications = 0

    /// Location
    case location = 1

    internal init?(from permission: AirshipPermission) {
        switch permission {
        case .displayNotifications:
            self = .displayNotifications
        case .location:
            self = .location
        @unknown default:
            return nil
        }
    }

    internal var airshipPermission: AirshipPermission {
        switch self {
        case .displayNotifications:
            return .displayNotifications
        case .location:
            return .location
        }
    }
}
