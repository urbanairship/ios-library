/* Copyright Airship and Contributors */

import Foundation
import Combine

/// Airship permissions manager.
///
/// Airship will provide the default handling for `Permission.postNotifications`. All other permissions will need
/// to be configured by the app by providing a `PermissionDelegate` for the given permissions.
@objc(UAPermissionsManager)
public final class AirshipPermissionsManager: NSObject, @unchecked Sendable {
    private let lock = AirshipLock()
    private var delegateMap: [AirshipPermission: AirshipPermissionDelegate] = [:]
    private var airshipEnablers: [
        AirshipPermission: [() async -> Void]
    ] = [:]

    private var queue: AirshipSerialQueue = AirshipSerialQueue()

    private var extenders: [
        AirshipPermission: [(AirshipPermissionStatus) async -> Void]
    ] = [:]
    
    private let statusUpdates: AirshipAsyncChannel<(AirshipPermission, AirshipPermissionStatus)> = AirshipAsyncChannel()
    private var notificationListener: AnyCancellable?
    
    init(notificationCenter: NotificationCenter = .default) {
        super.init()
        
        notificationListener = notificationCenter
            .publisher(for: AppStateTracker.didBecomeActiveNotification)
            .sink(receiveValue: { _ in
                Task { @MainActor [weak self] in
                    await self?.refreshPermissionStatuses()
                }
            })
    }

    var configuredPermissions: Set<AirshipPermission> {
        var result: Set<AirshipPermission>!
        lock.sync {
            result = Set(delegateMap.keys)
        }
        return result
    }
    
    /// Returns an async stream with status updates for the given permission
    ///
    /// - Parameters:
    ///     - permission: The permission.
    public func statusUpdate(for permission: AirshipPermission) -> AsyncStream<AirshipPermissionStatus> {

        return AsyncStream<AirshipPermissionStatus> { [weak self, statusUpdates] continuation in
            let task = Task { [weak self, statusUpdates] in
                if let startingStatus = await self?.checkPermissionStatus(permission) {
                    continuation.yield(startingStatus)
                }

                let updates = await statusUpdates.makeStream()
                    .filter({ $0.0 == permission })
                    .map({ $0.1 })

                for await item in updates {
                    continuation.yield(item)
                }
                continuation.finish()
            }
            
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
    
    /// - Note: For internal use only. :nodoc:
    @objc
    public func permissionStatusMap() async -> [String: String] {
        var map: [String: String] = [:]
        for permission in configuredPermissions {
            let status = await checkPermissionStatus(permission)
            map[permission.stringValue] = status.stringValue
        }
        return map
    }
    
    /// Sets a permission delegate.
    ///
    /// - Note: The delegate will be strongly retained.
    ///
    /// - Parameters:
    ///     - delegate: The delegate.
    ///     - permission: The permission.
    @objc
    public func setDelegate(
        _ delegate: AirshipPermissionDelegate?,
        permission: AirshipPermission
    ) {
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
    @MainActor
    public func checkPermissionStatus(
        _ permission: AirshipPermission
    ) async -> AirshipPermissionStatus {
        guard let delegate = self.permissionDelegate(permission) else {
            return .notDetermined
        }

        return await delegate.checkPermissionStatus()
    }

    /// Requests a permission.
    ///
    /// - Note: If no permission delegate is set for the given permission this will always return `.notDetermined`
    ///
    /// - Parameters:
    ///     - permission: The permission.
    @objc
    @MainActor
    public func requestPermission(
        _ permission: AirshipPermission
    ) async -> AirshipPermissionStatus {
        return await requestPermission(
            permission,
            enableAirshipUsageOnGrant: false
        )
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
    @MainActor
    public func requestPermission(
        _ permission: AirshipPermission,
        enableAirshipUsageOnGrant: Bool
    ) async -> AirshipPermissionStatus {
        let status: AirshipPermissionStatus? = try? await self.queue.run { @MainActor in
            guard let delegate = self.permissionDelegate(permission) else {
                return .notDetermined
            }

            let status = await delegate.requestPermission()

            if status == .granted {
                await self.onPermissionEnabled(
                    permission,
                    enableAirshipUsage: enableAirshipUsageOnGrant
                )
            }

            await self.onExtend(permission: permission, status: status)

            return status
        }
        
        let result = status ?? .notDetermined
        
        await statusUpdates.send((permission, result))

        return result
    }
    
    /// - Note: for internal use only.  :nodoc:
    func addRequestExtender(
        permission: AirshipPermission,
        extender: @escaping (AirshipPermissionStatus) async -> Void
    ) {
        lock.sync {
            if extenders[permission] == nil {
                extenders[permission] = [extender]
            } else {
                extenders[permission]?.append(extender)
            }
        }
    }
    
    /// - Note: for internal use only.  :nodoc:
    func addAirshipEnabler(
        permission: AirshipPermission,
        onEnable: @escaping () async -> Void
    ) {
        lock.sync {
            if airshipEnablers[permission] == nil {
                airshipEnablers[permission] = [onEnable]
            } else {
                airshipEnablers[permission]?.append(onEnable)
            }
        }
    }
    
    private func onPermissionEnabled(
        _ permission: AirshipPermission,
        enableAirshipUsage: Bool
    ) async {
        guard enableAirshipUsage else  { return }

        var enablers: [(() async -> Void)]!
        lock.sync {
            enablers = self.airshipEnablers[permission] ?? []
        }

        for enabler in enablers {
            await enabler()
        }
    }

    private func permissionDelegate(
        _ permission: AirshipPermission
    ) -> AirshipPermissionDelegate? {
        var delegate: AirshipPermissionDelegate?
        lock.sync {
            delegate = delegateMap[permission]
        }
        return delegate
    }
    
    @MainActor
    private func refreshPermissionStatuses() async {
        for permission in configuredPermissions {
            let status = await checkPermissionStatus(permission)
            await statusUpdates.send((permission, status))
        }
    }

    @MainActor
    func onExtend(
        permission: AirshipPermission,
        status: AirshipPermissionStatus
    ) async {
        var extenders: [((AirshipPermissionStatus) async -> Void)]!
        lock.sync {
            extenders = self.extenders[permission] ?? []
        }

        for extender in extenders {
            await extender(status)
        }
    }

}
