/* Copyright Airship and Contributors */

import UIKit
import AVFoundation
import AirshipCore

class PushHandler: NSObject, PushNotificationDelegate {

    func receivedBackgroundNotification(_ userInfo: [AnyHashable: Any], completionHandler: @escaping (UIBackgroundFetchResult) -> Swift.Void) {
        // Application received a background notification
        print("The application received a background notification");

        // Call the completion handler
        completionHandler(.noData)
    }

    func receivedForegroundNotification(_ userInfo: [AnyHashable : Any], completionHandler: @escaping () -> Swift.Void) {
        // Application received a foreground notification
        print("The application received a foreground notification");
        completionHandler()
    }

    func receivedNotificationResponse(_ notificationResponse: UNNotificationResponse, completionHandler: @escaping () -> Swift.Void) {
        let notificationContent = notificationResponse.notification.request.content
        NSLog("Received a notification response")
        NSLog("Alert Title:         \(notificationContent.title)")
        NSLog("Alert Body:          \(notificationContent.body)")
        NSLog("Action Identifier:   \(notificationResponse.actionIdentifier)")
        NSLog("Category Identifier: \(notificationContent.categoryIdentifier)")
        NSLog("Response Text:       \((notificationResponse as? UNTextInputNotificationResponse)?.userText ?? "")")

        completionHandler()
    }
        
    func extendPresentationOptions(
        _ options: UNNotificationPresentationOptions,
        notification: UNNotification,
        completionHandler: (UNNotificationPresentationOptions) -> Void
    ) {
        #if !targetEnvironment(macCatalyst)
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .list, .sound])
        } else {
            return completionHandler([.alert, .sound])
        }
        #else
        return completionHandler([.alert, .sound])
        #endif
    }
}
