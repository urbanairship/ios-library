/* Copyright 2017 Urban Airship and Contributors */

import UIKit
import AirshipKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UARegistrationDelegate {

    let simulatorWarningDisabledKey = "ua-simulator-warning-disabled"
    let pushHandler = PushHandler()

    var window: UIWindow?
    var inboxDelegate: InboxDelegate?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {
        self.failIfSimulator()

        // Populate AirshipConfig.plist with your app's info from https://go.urbanairship.com
        // or set runtime properties here.
        let config = UAConfig.default()

        if (config.validate() != true) {
            showInvalidConfigAlert()
            return true
        }

        // Set log level for debugging config loading (optional)
        // It will be set to the value in the loaded config upon takeOff
        UAirship.setLogLevel(UALogLevel.trace)

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

        NotificationCenter.default.addObserver(self, selector:#selector(AppDelegate.refreshMessageCenterBadge), name: NSNotification.Name.UAInboxMessageListUpdated, object: nil)

        return true
    }

    func showInvalidConfigAlert() {
        let alertController = UIAlertController.init(title: "Invalid AirshipConfig.plist", message: "The AirshipConfig.plist must be a part of the app bundle and include a valid appkey and secret for the selected production level.", preferredStyle:.actionSheet)
        alertController.addAction(UIAlertAction.init(title: "Exit Application", style: UIAlertActionStyle.default, handler: { (UIAlertAction) in
            exit(1)
        }))

        DispatchQueue.main.async {
            alertController.popoverPresentationController?.sourceView = self.window?.rootViewController?.view

            self.window?.rootViewController?.present(alertController, animated:true, completion: nil)
        }
    }

    func failIfSimulator() {
        // If it's not a simulator return early
        if (TARGET_OS_SIMULATOR == 0 && TARGET_IPHONE_SIMULATOR == 0) {
            return
        }

        if (UserDefaults.standard.bool(forKey: self.simulatorWarningDisabledKey)) {
            return
        }

        let alertController = UIAlertController(title: "Notice", message: "You will not be able to receive push notifications in the simulator.", preferredStyle: .alert)

        let disableAction = UIAlertAction(title: "Disable Warning", style: UIAlertActionStyle.default){ (UIAlertAction) -> Void in
            UserDefaults.standard.set(true, forKey:self.simulatorWarningDisabledKey)
        }
        alertController.addAction(disableAction)

        let cancelAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: nil)
        alertController.addAction(cancelAction)

        // Let the UI finish launching first so it doesn't complain about the lack of a root view controller
        // Delay execution of the block for 1/2 second.
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(0.5 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)) {
            alertController.popoverPresentationController?.sourceView = self.window?.rootViewController?.view

            self.window?.rootViewController?.present(alertController, animated: true, completion: nil)
        }
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        refreshMessageCenterBadge()
    }

    @objc func refreshMessageCenterBadge() {
        DispatchQueue.main.async {
            if self.window?.rootViewController is UITabBarController {
                let messageCenterTab: UITabBarItem = (self.window!.rootViewController! as! UITabBarController).tabBar.items![2]
                
                if (UAirship.inbox().messageList.unreadCount > 0) {
                    messageCenterTab.badgeValue = String(stringInterpolationSegment:UAirship.inbox().messageList.unreadCount)
                } else {
                    messageCenterTab.badgeValue = nil
                }
            }
        }
    }

    func registrationSucceeded(forChannelID channelID: String, deviceToken: String) {
        NotificationCenter.default.post(
            name: Notification.Name(rawValue: "channelIDUpdated"),
            object: self,
            userInfo:nil)
    }

}

