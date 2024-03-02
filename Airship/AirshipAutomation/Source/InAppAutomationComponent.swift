/* Copyright Airship and Contributors */

import Foundation

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
        _ notification: [AnyHashable: Any],
        completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        self.inAppAutomation.receivedRemoteNotification(notification, completionHandler: completionHandler)
    }

    func receivedNotificationResponse(_ response: UNNotificationResponse, completionHandler: @escaping () -> Void) {
        self.inAppAutomation.receivedNotificationResponse(response, completionHandler: completionHandler)
    }
}

