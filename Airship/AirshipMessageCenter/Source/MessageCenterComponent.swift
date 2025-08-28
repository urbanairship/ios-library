/* Copyright Airship and Contributors */



#if canImport(AirshipCore)
import AirshipCore
#endif

#if canImport(UIKit)
import UIKit
#endif


/// Actual airship component for MessageCenter. Used to hide AirshipComponent methods.
final class MessageCenterComponent : AirshipComponent, AirshipPushableComponent, Sendable {
    final let messageCenter: MessageCenter

    init(messageCenter: MessageCenter) {
        self.messageCenter = messageCenter
    }
    
    @MainActor
    public func deepLink(_ deepLink: URL) -> Bool {
        return self.messageCenter.deepLink(deepLink)
    }

    func receivedRemoteNotification(_ notification: AirshipJSON) async -> UABackgroundFetchResult {
        return await self.messageCenter.receivedRemoteNotification(notification)
    }

#if !os(tvOS)
    func receivedNotificationResponse(_ response: UNNotificationResponse) async {
        // no-op
    }
#endif
}

