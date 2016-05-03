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
import AirshipKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UARegistrationDelegate {

    let simulatorWarningDisabledKey = "ua-simulator-warning-disabled"
    let pushHandler = PushHandler()

    var window: UIWindow?
    var inboxDelegate: InboxDelegate?

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {

        self.failIfSimulator()

        // Set log level for debugging config loading (optional)
        // It will be set to the value in the loaded config upon takeOff
        UAirship.setLogLevel(UALogLevel.Trace)

        // Populate AirshipConfig.plist with your app's info from https://go.urbanairship.com
        // or set runtime properties here.
        let config = UAConfig.defaultConfig()
        config.messageCenterStyleConfig = "UAMessageCenterDefaultStyle"

        // You can then programmatically override the plist values:
        // config.developmentAppKey = "YourKey"
        // etc.

        // Call takeOff (which creates the UAirship singleton)
        UAirship.takeOff(config)

        // Print out the application configuration for debugging (optional)
        print("Config:\n \(config)")

        // Set the icon badge to zero on startup (optional)
        UAirship.push()?.resetBadge()

        // User notifications will not be enabled until userPushNotificationsEnabled is
        // enabled on UAPush. Once enabled, the setting will be persisted and the user
        // will be prompted to allow notifications. You should wait for a more appropriate
        // time to enable push to increase the likelihood that the user will accept
        // notifications.
        // UAirship.push()?.userPushNotificationsEnabled = true

        // Set a custom delegate for handling message center events
        self.inboxDelegate = InboxDelegate(rootViewController: (window?.rootViewController)!)
        UAirship.inbox().delegate = self.inboxDelegate
        UAirship.push().pushNotificationDelegate = pushHandler
        UAirship.push().registrationDelegate = self

        NSNotificationCenter.defaultCenter().addObserver(self, selector:#selector(AppDelegate.refreshMessageCenterBadge), name: UAInboxMessageListUpdatedNotification, object: nil)

        return true
    }

    func failIfSimulator() {
        // If it's not a simulator return early
        if (TARGET_OS_SIMULATOR == 0 && TARGET_IPHONE_SIMULATOR == 0) {
            return
        }

        if (NSUserDefaults.standardUserDefaults().boolForKey(self.simulatorWarningDisabledKey)) {
            return
        }

        let alertController = UIAlertController(title: "Notice", message: "You will not be able to receive push notifications in the simulator.", preferredStyle: .Alert)
        let disableAction = UIAlertAction(title: "Disable Warning", style: UIAlertActionStyle.Default){ (UIAlertAction) -> Void in
            NSUserDefaults.standardUserDefaults().setBool(true, forKey:self.simulatorWarningDisabledKey)
        }
        alertController.addAction(disableAction)

        let cancelAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Cancel, handler: nil)
        alertController.addAction(cancelAction)

        // Let the UI finish launching first so it doesn't complain about the lack of a root view controller
        // Delay execution of the block for 1/2 second.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(0.5 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) {
            self.window?.rootViewController?.presentViewController(alertController, animated: true, completion: nil)
        }
    }

    func applicationWillEnterForeground(application: UIApplication) {
        refreshMessageCenterBadge()
    }

    func refreshMessageCenterBadge() {

        if self.window?.rootViewController is UITabBarController {
            let messageCenterTab: UITabBarItem = (self.window!.rootViewController! as! UITabBarController).tabBar.items![2]

            if (UAirship.inbox().messageList.unreadCount > 0) {
                messageCenterTab.badgeValue = String(stringInterpolationSegment:UAirship.inbox().messageList.unreadCount)
            } else {
                messageCenterTab.badgeValue = nil
            }
        }
    }

    func registrationSucceededForChannelID(channelID: String, deviceToken: String) {
        NSNotificationCenter.defaultCenter().postNotificationName(
            "channelIDUpdated",
            object: self,
            userInfo:nil)
    }

}

