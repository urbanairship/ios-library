/* Copyright Airship and Contributors */

import Foundation

/// Airship permissions manager.
///
/// Airship will provide the default handling for `Permission.postNotifications`. All other permissions will need
/// to be configured by the app by providing a `PermissionDelegate` for the given permissions.
@objc(UAPermissionsManager)
public class PermissionsManager: NSObject {
    private let lock = Lock()
    private var delegateMap: [Permission: PermissionDelegate] = [:]
    private var airshipEnablers: [Permission: [(() -> Void)]] = [:]
    private var extenders: [Permission: [((PermissionStatus, @escaping () -> Void) -> Void)]] = [:]

    private let mainDispatcher = UADispatcher.main

    var configuredPermissions: Set<Permission> {
        var result: Set<Permission>!
        lock.sync {
            result = Set(delegateMap.keys)
        }
        return result
    }

    /// - Note: For internal use only. :nodoc:
    @objc
    public func permissionStatusMap(completionHandler: @escaping ([String : String]) -> Void) {
        
        var map: [String : String] = [:]
        let group = DispatchGroup()
        
        configuredPermissions.forEach { permission in
            group.enter()
            checkPermissionStatus(permission) { status in
                map[permission.stringValue] = status.stringValue
                group.leave()
            }
        }
        
        group.notify(queue: DispatchQueue.global()) {
            completionHandler(map);
        }
        
    }

    /// Sets a permission delegate.
    ///
    /// - Note: The delegate will be strongly retained.
    ///
    /// - Parameters:
    ///     - delegate: The delegate.
    ///     - permission: The permission.
    @objc
    public func setDelegate(_ delegate: PermissionDelegate?, permission: Permission) {
        lock.sync {
            delegateMap[permission] = delegate
        }
    }

    /// Checks a permission status.
    ///
    /// - Note: If no delegate is set for the given permission this will always return `.notDetermined`.
    ///
    /// - Parameters:
    ///     - permission: The permission.
    ///     - completionHandler: The completion handler.
    @objc
    public func checkPermissionStatus(_ permission: Permission,
                                      completionHandler: @escaping (PermissionStatus) -> Void) {

        mainDispatcher.dispatchAsyncIfNecessary {
            guard let delegate = self.permissionDelegate(permission) else {
                completionHandler(.notDetermined)
                return
            }

            delegate.checkPermissionStatus { status in
                self.mainDispatcher.dispatchAsyncIfNecessary {
                    completionHandler(status)
                }
            }
        }
    }

    /// Requests a permission.
    ///
    /// - Note: If no permission delegate is set for the given permission this will always return `.notDetermined`
    ///
    /// - Parameters:
    ///     - permission: The permission.
    @objc
    public func requestPermission(_ permission: Permission) {
        return requestPermission(permission,
                                 enableAirshipUsageOnGrant: false,
                                 completionHandler:nil)
    }

    /// Requests a permission.
    ///
    /// - Note: If no permission delegate is set for the given permission this will always return `.notDetermined`
    ///
    /// - Parameters:
    ///     - permission: The permission.
    ///     - completionHandler: The completion handler.
    @objc
    public func requestPermission(_ permission: Permission,
                                  completionHandler: ((PermissionStatus) -> Void)?) {
        return requestPermission(permission,
                                 enableAirshipUsageOnGrant: false,
                                 completionHandler: completionHandler);
    }

    /// Requests a permission.
    ///
    /// - Note: If no permission delegate is set for the given permission this will always return `.notDetermined`
    ///
    /// - Parameters:
    ///     - permission: The permission.
    ///     - enableAirshipUsageOnGrant: `true` to allow any Airship features that need the permission to be enabled as well, e.g., enabling push privacy manager feature and user notifications if `.postNotifications` is granted.
    ///     - completionHandler: The completion handler.
    @objc
    public func requestPermission(_ permission: Permission,
                                  enableAirshipUsageOnGrant: Bool,
                                  completionHandler: ((PermissionStatus) -> Void)?) {

        self.mainDispatcher.dispatchAsyncIfNecessary {
            guard let delegate = self.permissionDelegate(permission) else {
                completionHandler?(.notDetermined)
                return
            }

            delegate.requestPermission { status in
                self.mainDispatcher.dispatchAsyncIfNecessary {
                    if (status == .granted) {
                        self.onPermissionEnabled(permission, enableAirshipUsage: enableAirshipUsageOnGrant)
                    }
                    PermissionsManager.callExtenders(self.extenders[permission], status: status) {
                        completionHandler?(status)
                    }
                }
            }
        }
    }

    /// - Note: for internal use only.  :nodoc:
    func addRequestExtender(permission: Permission,
                            extender: @escaping (PermissionStatus, @escaping () -> Void) -> Void) {
        if (extenders[permission] == nil) {
            extenders[permission] = [extender]
        } else {
            extenders[permission]?.append(extender)
        }
    }

    /// - Note: for internal use only.  :nodoc:
    @objc
    public func addAirshipEnabler(permission: Permission, onEnable: @escaping () -> Void) {
        if (airshipEnablers[permission] == nil) {
            airshipEnablers[permission] = [onEnable]
        } else {
            airshipEnablers[permission]?.append(onEnable)
        }
    }

    private func onPermissionEnabled(_ permission: Permission, enableAirshipUsage: Bool) {
        if (enableAirshipUsage) {
            self.airshipEnablers[permission]?.forEach { $0() }
        }
    }

    private func permissionDelegate(_ permission: Permission) -> PermissionDelegate? {
        var delegate: PermissionDelegate?
        lock.sync {
            delegate = delegateMap[permission]
        }
        return delegate
    }

    class func callExtenders(_ extenders: [(PermissionStatus, @escaping () -> Void) -> Void]?,
                       status: PermissionStatus,
                       completionHandler: @escaping () -> Void) {

        guard var remaining = extenders, remaining.count > 0 else {
            completionHandler()
            return
        }

        let next = remaining.removeFirst()
        next(status) {
            PermissionsManager.callExtenders(remaining,
                                             status: status,
                                             completionHandler: completionHandler)
        }
    }
}
