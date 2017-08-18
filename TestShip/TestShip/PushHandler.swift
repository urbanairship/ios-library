/* Copyright 2017 Urban Airship and Contributors */

import UIKit
import AVFoundation
import AirshipKit

/*
 * The Test Ship push notification delegate.
 */
class PushHandler: NSObject, UAPushNotificationDelegate {

    var onReceivedForegroundNotification:(_ notificationContent: UANotificationContent)->Void = {_ in }
    var onReceivedBackgroundNotification:(_ notificationContent: UANotificationContent)->Void = {_ in }
    var onReceivedNotificationResponse:(_ notificationResponse: UANotificationResponse)->Void = {_ in }

    func receivedBackgroundNotification(_ notificationContent: UANotificationContent, completionHandler: @escaping (UIBackgroundFetchResult) -> Swift.Void) {

        onReceivedBackgroundNotification(notificationContent)

        // Call the completion handler
        completionHandler(.noData)
    }

    func receivedForegroundNotification(_ notificationContent: UANotificationContent, completionHandler: @escaping () -> Swift.Void) {

        onReceivedForegroundNotification(notificationContent)

        completionHandler()
    }

    func receivedNotificationResponse(_ notificationResponse: UANotificationResponse, completionHandler: @escaping () -> Swift.Void) {

        onReceivedNotificationResponse(notificationResponse)

        let notificationContent = notificationResponse.notificationContent
        NSLog("Received a notification response")
        NSLog("Alert Title:         \(notificationContent.alertTitle ?? "nil")")
        NSLog("Alert Body:          \(notificationContent.alertBody ?? "nil")")
        NSLog("Action Identifier:   \(notificationResponse.actionIdentifier)")
        NSLog("Category Identifier: \(notificationContent.categoryIdentifier ?? "nil")")
        NSLog("Response Text:       \(notificationResponse.responseText)")

        completionHandler()
    }
}
