/* Copyright Airship and Contributors */

public import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Airship permissions manager.
///
/// Airship will provide the default handling for `UAPermission.displayNotifications`. All other permissions will need
/// to be configured by the app by providing a `UAAirshipPermissionDelegate` for the given permissions.
@objc
public final class UAPermissionsManager: NSObject, Sendable {

    /// Sets a permission delegate.
    ///
    /// - Note: The delegate will be strongly retained.
    ///
    /// - Parameters:
    ///     - delegate: The delegate.
    ///     - permission: The permission.
    @objc
    public func setDelegate(
        _ delegate: (any UAAirshipPermissionDelegate)?,
        permission: UAPermission
    ) {
        if let delegate = delegate {
            let wrapper = UAPermissionDelegateWrapper(delegate: delegate)
            Airship.permissionsManager.setDelegate(wrapper, permission: permission.airshipPermission)
        } else {
            Airship.permissionsManager.setDelegate(nil, permission: permission.airshipPermission)
        }
    }

    /// Checks a permission status.
    ///
    /// - Note: If no delegate is set for the given permission this will always return `.notDetermined`.
    ///
    /// - Parameters:
    ///     - permission: The permission.
    ///     - completionHandler: The completion handler to call with the permission status.
    @objc
    @MainActor
    public func checkPermissionStatus(
        _ permission: UAPermission,
        completionHandler: @escaping (UAPermissionStatus) -> Void
    ) {
        Task { @MainActor in
            let status = await Airship.permissionsManager.checkPermissionStatus(permission.airshipPermission)
            completionHandler(UAPermissionStatus(status))
        }
    }

    /// Requests a permission.
    ///
    /// - Note: If no permission delegate is set for the given permission this will always return `.notDetermined`
    ///
    /// - Parameters:
    ///     - permission: The permission.
    ///     - completionHandler: The completion handler to call with the permission status.
    @objc
    @MainActor
    public func requestPermission(
        _ permission: UAPermission,
        completionHandler: @escaping (UAPermissionStatus) -> Void
    ) {
        Task { @MainActor in
            let status = await Airship.permissionsManager.requestPermission(permission.airshipPermission)
            completionHandler(UAPermissionStatus(status))
        }
    }

    /// Requests a permission with option to enable Airship usage on grant.
    ///
    /// - Note: If no permission delegate is set for the given permission this will always return `.notDetermined`
    ///
    /// - Parameters:
    ///     - permission: The permission.
    ///     - enableAirshipUsageOnGrant: `true` to allow any Airship features that need the permission to be enabled as well.
    ///     - completionHandler: The completion handler to call with the permission status.
    @objc
    @MainActor
    public func requestPermission(
        _ permission: UAPermission,
        enableAirshipUsageOnGrant: Bool,
        completionHandler: @escaping (UAPermissionStatus) -> Void
    ) {
        Task { @MainActor in
            let status = await Airship.permissionsManager.requestPermission(
                permission.airshipPermission,
                enableAirshipUsageOnGrant: enableAirshipUsageOnGrant
            )
            completionHandler(UAPermissionStatus(status))
        }
    }
}
