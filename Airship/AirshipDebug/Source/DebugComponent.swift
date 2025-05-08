/* Copyright Airship and Contributors */

import Foundation
@preconcurrency import UserNotifications

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Actual airship component for AirshipDebugManager. Used to hide AirshipComponent methods.
final class DebugComponent : AirshipComponent, AirshipPushableComponent {
    final let debugManager: AirshipDebugManager

    init(debugManager: AirshipDebugManager) {
        self.debugManager = debugManager
    }

    @MainActor
    func receivedRemoteNotification(
        _ notification: AirshipCore.AirshipJSON
    ) async -> AirshipCore.UABackgroundFetchResult {
        return await self.debugManager.receivedRemoteNotification(notification)
    }

#if !os(tvOS)
    @MainActor
    func receivedNotificationResponse(
        _ response: UNNotificationResponse
    ) async {
        return await self.debugManager.receivedNotificationResponse(response)
    }
#endif

}

