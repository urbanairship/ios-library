/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Actual airship component for MessageCenter. Used to hide AirshipComponent methods.
final class MessageCenterComponent : AirshipComponent, AirshipPushableComponent {
    final let messageCenter: MessageCenter

    init(messageCenter: MessageCenter) {
        self.messageCenter = messageCenter
    }
    
    @MainActor
    public func deepLink(_ deepLink: URL) -> Bool {
        return self.messageCenter.deepLink(deepLink)
    }

    @MainActor
    public func receivedRemoteNotification(
        _ notification: [AnyHashable: Any],
        completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        self.messageCenter.receivedRemoteNotification(notification, completionHandler: completionHandler)
    }
}

