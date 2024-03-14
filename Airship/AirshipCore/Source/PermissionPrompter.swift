/* Copyright Airship and Contributors */

import Foundation
import Combine

typealias PermissionResultReceiver = @Sendable (
    AirshipPermission, AirshipPermissionStatus, AirshipPermissionStatus
) async -> Void

protocol PermissionPrompter: Sendable {

    func prompt(
        permission: AirshipPermission,
        enableAirshipUsage: Bool,
        fallbackSystemSettings: Bool
    ) async ->  (AirshipPermissionStatus, AirshipPermissionStatus)

}

struct AirshipPermissionPrompter: PermissionPrompter {

    private let permissionsManager: AirshipPermissionsManager
    private let notificationCenter: NotificationCenter

    init(
        permissionsManager: AirshipPermissionsManager,
        notificationCenter: NotificationCenter = NotificationCenter.default
    ) {
        self.permissionsManager = permissionsManager
        self.notificationCenter = notificationCenter
    }

    @MainActor
    func prompt(
        permission: AirshipPermission,
        enableAirshipUsage: Bool,
        fallbackSystemSettings: Bool
    ) async ->  (AirshipPermissionStatus, AirshipPermissionStatus) {

        let startResult = await self.permissionsManager.checkPermissionStatus(permission)
        if fallbackSystemSettings && startResult == .denied {
            #if !os(watchOS)
            let endResult = await self.requestSystemSettingsChange(permission: permission)
            #else
            let endResult = await self.permissionsManager.requestPermission(
                permission,
                enableAirshipUsageOnGrant: enableAirshipUsage
            )
            #endif
            return (startResult, endResult)

        } else {
            let endResult = await self.permissionsManager.requestPermission(
                permission,
                enableAirshipUsageOnGrant: enableAirshipUsage
            )

            return (startResult, endResult)
        }
    }
    
    #if !os(watchOS)

    @MainActor
    private func requestSystemSettingsChange(
        permission: AirshipPermission
    ) async -> AirshipPermissionStatus {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            await UIApplication.shared.open(url, options: [:])
            await waitNextOpen()
        } else {
            AirshipLogger.error("Unable to navigate to system settings.")
        }

        return await self.permissionsManager.checkPermissionStatus(permission)
    }


    @MainActor
    private func waitNextOpen() async {
        var subscription: AnyCancellable?
        await withCheckedContinuation { continuation in
            subscription = self.notificationCenter.publisher(for: AppStateTracker.didBecomeActiveNotification)
                .sink { _ in
                    continuation.resume()
                }
        }

        subscription?.cancel()
    }
    #endif

}
