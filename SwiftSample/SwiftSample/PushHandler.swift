/* Copyright 2010-2019 Urban Airship and Contributors */

import UIKit
import AVFoundation
import AirshipKit

class PushHandler: NSObject, UAPushNotificationDelegate {

    func receivedBackgroundNotification(_ notificationContent: UANotificationContent, completionHandler: @escaping (UIBackgroundFetchResult) -> Swift.Void) {
        // Application received a background notification
        print("The application received a background notification");

        // Call the completion handler
        completionHandler(.noData)
    }

    func receivedForegroundNotification(_ notificationContent: UANotificationContent, completionHandler: @escaping () -> Swift.Void) {
        // Application received a foreground notification
        print("The application received a foreground notification");
        completionHandler()
    }

    func receivedNotificationResponse(_ notificationResponse: UANotificationResponse, completionHandler: @escaping () -> Swift.Void) {
        let notificationContent = notificationResponse.notificationContent
        NSLog("Received a notification response")
        NSLog("Alert Title:         \(notificationContent.alertTitle ?? "nil")")
        NSLog("Alert Body:          \(notificationContent.alertBody ?? "nil")")
        NSLog("Action Identifier:   \(notificationResponse.actionIdentifier)")
        NSLog("Category Identifier: \(notificationContent.categoryIdentifier ?? "nil")")
        NSLog("Response Text:       \(notificationResponse.responseText)")

        completionHandler()
    }

    func presentationOptions(for notification: UNNotification) -> UNNotificationPresentationOptions {
        return [.alert, .sound]
    }

}
