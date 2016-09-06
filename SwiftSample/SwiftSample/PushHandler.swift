/*
Copyright 2009-2016 Urban Airship Inc. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation
and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

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

        // Use alert presentation options if iOS version < iOS 10
        if (ProcessInfo.processInfo.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 10, minorVersion: 0, patchVersion: 0)) == false) {

            // Only display an alert dialog if the push does not contain a rich push message id.
            // If it does, allow the InboxDelegate's richPushMessageAvailable: to handle it.
            if (UAInboxUtils.inboxMessageID(fromNotification: notificationContent.notificationInfo) == nil) {
                let alertController: UIAlertController = UIAlertController()

                alertController.title = notificationContent.alertTitle ?? NSLocalizedString("UA_Notification_Title", tableName: "UAPushUI", comment: "System Push Settings Label")
                alertController.message = notificationContent.alertBody

                let cancelAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.cancel, handler: nil)
                alertController.addAction(cancelAction)

                let topController = UIApplication.shared.keyWindow!.rootViewController! as UIViewController
                alertController.popoverPresentationController?.sourceView = topController.view

                topController.present(alertController, animated:true, completion:nil)
            }

            // Call the completion handler
            completionHandler()
        }
    }

    func receivedNotificationResponse(_ notificationResponse: UANotificationResponse, completionHandler: @escaping () -> Swift.Void) {
        print("The user selected the following action identifier:%@", notificationResponse.actionIdentifier);

        // Call the completion handler
        completionHandler()
    }

    @available(iOS 10.0, *)
    func presentationOptions(for notification: UNNotification) -> UNNotificationPresentationOptions {
        return .alert
    }

}
