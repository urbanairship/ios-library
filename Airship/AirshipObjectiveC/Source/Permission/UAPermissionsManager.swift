/* Copyright Airship and Contributors */

public import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Airship permissions manager for Objective-C compatibility
@objc
public final class UAPermissionsManager: NSObject, Sendable {

    /// Sets a permission delegate.
    /// - Parameters:
    ///   - delegate: The delegate. Will be strongly retained.
    ///   - permission: The permission.
    @objc
    public static func setDelegate(_ delegate: (any UAPermissionDelegate)?, permission: UAPermission) {
        Task { @MainActor in
            if let delegate = delegate {
                let wrapper = UAPermissionDelegateWrapper(delegate: delegate)
                Airship.permissionsManager.setDelegate(wrapper, permission: permission.airshipPermission)
            } else {
                Airship.permissionsManager.setDelegate(nil, permission: permission.airshipPermission)
            }
        }
    }

    /// Checks the permission status.
    /// - Parameters:
    ///   - permission: The permission.
    ///   - completionHandler: Completion handler with the permission status.
    @objc
    public static func checkPermissionStatus(_ permission: UAPermission, completionHandler: @escaping (UAPermissionStatus) -> Void) {
        Task { @MainActor in
            let status = await Airship.permissionsManager.checkPermissionStatus(permission.airshipPermission)
            completionHandler(UAPermissionStatus(from: status))
        }
    }

    /// Requests the permission.
    /// - Parameters:
    ///   - permission: The permission.
    ///   - completionHandler: Completion handler with the permission status.
    @objc
    public static func requestPermission(_ permission: UAPermission, completionHandler: @escaping (UAPermissionStatus) -> Void) {
        Task { @MainActor in
            let status = await Airship.permissionsManager.requestPermission(permission.airshipPermission)
            completionHandler(UAPermissionStatus(from: status))
        }
    }
}
