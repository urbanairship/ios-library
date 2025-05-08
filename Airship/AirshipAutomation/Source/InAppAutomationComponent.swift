/* Copyright Airship and Contributors */

import Foundation
@preconcurrency
import UserNotifications

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AirshipCore)
import AirshipCore
#endif


/// Actual airship component for InAppAutomation. Used to hide AirshipComponent methods.
final class InAppAutomationComponent: AirshipComponent, AirshipPushableComponent {
    let inAppAutomation: InAppAutomation

    init(inAppAutomation: InAppAutomation) {
        self.inAppAutomation = inAppAutomation
    }

    @MainActor
    func airshipReady() {
        self.inAppAutomation.airshipReady()
    }

    func receivedRemoteNotification(
        _ notification: AirshipJSON
    ) async -> UABackgroundFetchResult {
        return await self.inAppAutomation.receivedRemoteNotification(notification)
    }

#if !os(tvOS)
    func receivedNotificationResponse(_ response: UNNotificationResponse) async {
        await self.inAppAutomation.receivedNotificationResponse(response)
    }
#endif
}

