/* Copyright Airship and Contributors */

import AVFoundation
import AirshipCore
import UIKit

class PushHandler: NSObject, PushNotificationDelegate {
    func extendPresentationOptions(_ options: UNNotificationPresentationOptions, notification: UNNotification, completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {}
    

    func receivedBackgroundNotification(
        _ userInfo: [AnyHashable: Any],
        completionHandler: @escaping (UIBackgroundFetchResult) -> Swift.Void
    ) {
        // Application received a background notification
        print("The application received a background notification")

        // Call the completion handler
        completionHandler(.noData)
    }

    func receivedForegroundNotification(
        _ userInfo: [AnyHashable: Any],
        completionHandler: @escaping () -> Swift.Void
    ) {
        // Application received a foreground notification
        print("The application received a foreground notification")

        // Let system handle it
        completionHandler()
    }

    func extend(
        _ options: UNNotificationPresentationOptions = [],
        notification: UNNotification
    ) -> UNNotificationPresentationOptions {
        return [.badge]
    }
}
