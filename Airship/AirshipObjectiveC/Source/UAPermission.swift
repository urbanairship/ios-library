/* Copyright Airship and Contributors */

public import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Airship permissions. Used with `UAPermissionsManager`
@objc
public enum UAPermission: Int, Sendable {
    /// Post notifications
    case displayNotifications = 0

    /// Location
    case location = 1

    var airshipPermission: AirshipPermission {
        switch self {
        case .displayNotifications: return .displayNotifications
        case .location: return .location
        }
    }

    init(_ permission: AirshipPermission) {
        switch permission {
        case .displayNotifications: self = .displayNotifications
        case .location: self = .location
        @unknown default: self = .displayNotifications
        }
    }
}

/// Permission status
@objc
public enum UAPermissionStatus: Int, Sendable {
    /// Could not determine the permission status.
    case notDetermined = 0

    /// Permission is granted.
    case granted = 1

    /// Permission is denied.
    case denied = 2

    var airshipStatus: AirshipPermissionStatus {
        switch self {
        case .notDetermined: return .notDetermined
        case .granted: return .granted
        case .denied: return .denied
        }
    }

    init(_ status: AirshipPermissionStatus) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .granted: self = .granted
        case .denied: self = .denied
        @unknown default: self = .notDetermined
        }
    }
}

/// Protocol to be implemented by permission delegates.
@objc
public protocol UAAirshipPermissionDelegate: Sendable {

    /// Called when a permission needs to be checked.
    /// - Parameter completionHandler: The completion handler to call with the permission status.
    @MainActor
    func checkPermissionStatus(completionHandler: @escaping (UAPermissionStatus) -> Void)

    /// Called when a permission should be requested.
    /// - Note: A permission might be already granted when this method is called.
    /// - Parameter completionHandler: The completion handler to call with the permission status.
    @MainActor
    func requestPermission(completionHandler: @escaping (UAPermissionStatus) -> Void)
}

/// Internal wrapper to convert UAAirshipPermissionDelegate to AirshipPermissionDelegate
final class UAPermissionDelegateWrapper: AirshipPermissionDelegate, @unchecked Sendable {

    private let forwardDelegate: any UAAirshipPermissionDelegate

    init(delegate: any UAAirshipPermissionDelegate) {
        self.forwardDelegate = delegate
    }

    @MainActor
    func checkPermissionStatus() async -> AirshipPermissionStatus {
        await withCheckedContinuation { continuation in
            self.forwardDelegate.checkPermissionStatus { status in
                continuation.resume(returning: status.airshipStatus)
            }
        }
    }

    @MainActor
    func requestPermission() async -> AirshipPermissionStatus {
        await withCheckedContinuation { continuation in
            self.forwardDelegate.requestPermission { status in
                continuation.resume(returning: status.airshipStatus)
            }
        }
    }
}
