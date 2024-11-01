/* Copyright Airship and Contributors */

import Foundation

/// Airship permissions manager.
///
/// Airship will provide the default handling for `Permission.postNotifications`. All other permissions will need
/// to be configured by the app by providing a `PermissionDelegate` for the given permissions.
public final class AirshipPermissionsManager: @unchecked Sendable {
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
    private let appStateTracker: AppStateTrackerProtocol
    private let systemSettingsNavigator: SystemSettingsNavigatorProtocol

    @MainActor
    init(
        appStateTracker: AppStateTrackerProtocol? = nil,
        systemSettingsNavigator: SystemSettingsNavigatorProtocol = SystemSettingsNavigator()
    ) {
        self.appStateTracker = appStateTracker ?? AppStateTracker.shared
        self.systemSettingsNavigator = systemSettingsNavigator

        Task { @MainActor [weak self] in
            guard let updates = self?.appStateTracker.stateUpdates else { return }
            for await update in updates {
                if (update == .active) {
                    await self?.refreshPermissionStatuses()
                }
            }
        }
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
    ///     - enableAirshipUsageOnGrant: `true` to allow any Airship features that need the permission to be enabled as well, e.g., enabling push privacy manager feature and user notifications if `.displayNotifications` is granted.
    ///     - completionHandler: The completion handler.
    @MainActor
    public func requestPermission(
        _ permission: AirshipPermission,
        enableAirshipUsageOnGrant: Bool
    ) async -> AirshipPermissionStatus {
        return await requestPermission(
            permission,
            enableAirshipUsageOnGrant: enableAirshipUsageOnGrant,
            fallback: .none
        ).endStatus
    }

    /// Requests a permission.
    ///
    /// - Parameters:
    ///     - permission: The permission.
    ///     - enableAirshipUsageOnGrant: `true` to allow any Airship features that need the permission to be enabled as well, e.g., enabling push privacy manager feature and user notifications if `.displayNotifications` is granted.
    ///     - fallback: The fallback behavior if the permission is alreay denied.
    /// - Returns: A `AirshipPermissionResult` with the starting and ending status If no permission delegate is
    /// set for the given permission the status will be `.notDetermined`
    @MainActor
    public func requestPermission(
        _ permission: AirshipPermission,
        enableAirshipUsageOnGrant: Bool,
        fallback: PromptPermissionFallback
    ) async -> AirshipPermissionResult {
        let status: AirshipPermissionResult? = try? await self.queue.run { @MainActor in
            guard let delegate = self.permissionDelegate(permission) else {
                return AirshipPermissionResult.notDetermined
            }

            let startingStatus = await delegate.checkPermissionStatus()
            var endStatus: AirshipPermissionStatus = await delegate.requestPermission()

            if startingStatus == .denied, endStatus == .denied {
                switch fallback {
                case .none:
                    endStatus = .denied
                case .systemSettings:
                    if await self.systemSettingsNavigator.open(for: permission) {
                        await self.appStateTracker.waitForActive()
                        endStatus = await delegate.checkPermissionStatus()
                    } else {
                        endStatus = .denied
                    }
                case .callback(let callback):
                    await callback()
                    endStatus = await delegate.checkPermissionStatus()
                }
            }

            if endStatus == .granted {
                await self.onPermissionEnabled(
                    permission,
                    enableAirshipUsage: enableAirshipUsageOnGrant
                )
            }

            await self.onExtend(permission: permission, status: endStatus)

            return AirshipPermissionResult(startStatus: startingStatus, endStatus: endStatus)
        }

        let result = status ?? AirshipPermissionResult.notDetermined

        await statusUpdates.send((permission, result.endStatus))

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

public struct AirshipPermissionResult: Sendable {
    /// Starting status
    public var startStatus: AirshipPermissionStatus

    /// Ending status
    public var endStatus: AirshipPermissionStatus

    public init(startStatus: AirshipPermissionStatus, endStatus: AirshipPermissionStatus) {
        self.startStatus = startStatus
        self.endStatus = endStatus
    }

    static var notDetermined: AirshipPermissionResult {
        AirshipPermissionResult(startStatus: .notDetermined, endStatus: .notDetermined)
    }
}



/// Prompt permission fallback to be used if the requested permission is already denied.
public enum PromptPermissionFallback: Sendable {
    /// No fallback
    case none
    /// Navigate to system settings
    case systemSettings
    // Custom callback
    case callback(@MainActor @Sendable () async -> Void)
}



protocol SystemSettingsNavigatorProtocol: Sendable {
    @MainActor
    func open(for: AirshipPermission) async -> Bool
}

struct SystemSettingsNavigator: SystemSettingsNavigatorProtocol {
#if !os(watchOS)
    @MainActor
    func open(for permission: AirshipPermission) async -> Bool {
        if let url = systemSettingURLForPermission(permission) {
            return await UIApplication.shared.open(url, options: [:])
        } else {
            return false
        }
    }
    
    @MainActor
    private func systemSettingURLForPermission(_ permission: AirshipPermission) -> URL? {
        let string = switch(permission) {
        case .displayNotifications:
            if #available(iOS 16.0, tvOS 16.0, macCatalyst 16.0, visionOS 1.0, *) {
                UIApplication.openNotificationSettingsURLString
            } else if #available(iOS 15.4, tvOS 15.4, macCatalyst 15.4, *) {
                UIApplicationOpenNotificationSettingsURLString
            } else {
                UIApplication.openSettingsURLString
            }
        case .location:
            UIApplication.openSettingsURLString
        }

        return URL(string: string)
    }
    #else

    @MainActor
    func open(for permission: AirshipPermission) async -> Bool {
       return false
    }

    #endif

}
