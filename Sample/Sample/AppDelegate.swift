/* Copyright Airship and Contributors */

import UIKit

import AirshipCore
import AirshipMessageCenter
import AirshipAutomation
#if DEBUG
import AirshipDebug
#endif

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, RegistrationDelegate, DeepLinkDelegate, InAppMessageCachePolicyDelegate {
    let simulatorWarningDisabledKey = "ua-simulator-warning-disabled"
    let pushHandler = PushHandler()

    let HomeStoryboardID = "home"
    let MessageCenterStoryboardID = "message_center"
    let SettingsStoryboardID = "push_settings"
    let DebugStoryboardID = "debug"
    let InAppAutomationStoryboardID = "in_app_automation"

    let HomeTab = 0;
    let MessageCenterTab = 1;
    let SettingsTab = 2;
    let DebugTab = 3;

    var window: UIWindow?
    var messageCenterDelegate: MessageCenterDelegate?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        self.failIfSimulator()

        // Populate AirshipConfig.plist with your app's info from https://go.urbanairship.com
        // or set runtime properties here.
        let config = Config.default()

        if (config.validate() != true) {
            showInvalidConfigAlert()
            return true
        }

        // Set log level for debugging config loading (optional)
        // It will be set to the value in the loaded config upon takeOff
        Airship.logLevel = .trace

        config.messageCenterStyleConfig = "UAMessageCenterDefaultStyle"

        // You can then programmatically override the plist values:
        // config.developmentAppKey = "YourKey"
        // etc.

        // Call takeOff (which creates the UAirship singleton)
        Airship.takeOff(config, launchOptions: launchOptions)

        // Print out the application configuration for debugging (optional)
        print("Config:\n \(config)")

        // Set the icon badge to zero on startup (optional)
        Airship.push.resetBadge()

        // User notifications will not be enabled until userPushNotificationsEnabled is
        // enabled on UAPush. Once enabled, the setting will be persisted and the user
        // will be prompted to allow notifications. You should wait for a more appropriate
        // time to enable push to increase the likelihood that the user will accept
        // notifications.
        // Airship.push?.userPushNotificationsEnabled = true

        // Set a custom delegate for handling message center events
        self.messageCenterDelegate = MessageCenterDelegate(tabBarController: window!.rootViewController as! UITabBarController)
        MessageCenter.shared.displayDelegate = self.messageCenterDelegate
        Airship.push.pushNotificationDelegate = pushHandler
        Airship.push.registrationDelegate = self
        Airship.shared.deepLinkDelegate = self
        InAppAutomation.shared.inAppMessageManager.assetManager.cachePolicyDelegate = self;

        NotificationCenter.default.addObserver(self, selector:#selector(AppDelegate.refreshMessageCenterBadge), name: NSNotification.Name.UAInboxMessageListUpdated, object: nil)
        
        return true
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb else { return false }
        
        let targetTab = (Int)(userActivity.webpageURL?.query ?? "0")
        let tabController = window!.rootViewController as! UITabBarController
        
        tabController.selectedIndex = targetTab!
        
        return true
    }
    
    func showInvalidConfigAlert() {
        let alertController = UIAlertController.init(title: "Invalid AirshipConfig.plist", message: "The AirshipConfig.plist must be a part of the app bundle and include a valid appkey and secret for the selected production level.", preferredStyle:.actionSheet)
        alertController.addAction(UIAlertAction.init(title: "Exit Application", style: UIAlertAction.Style.default, handler: { (UIAlertAction) in
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

        let disableAction = UIAlertAction(title: "Disable Warning", style: UIAlertAction.Style.default){ (UIAlertAction) -> Void in
            UserDefaults.standard.set(true, forKey:self.simulatorWarningDisabledKey)
        }
        alertController.addAction(disableAction)

        let cancelAction = UIAlertAction(title: "Cancel", style: UIAlertAction.Style.cancel, handler: nil)
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
                let messageCenterTab: UITabBarItem = (self.window!.rootViewController! as! UITabBarController).tabBar.items![self.MessageCenterTab]

                if (MessageCenter.shared.messageList.unreadCount > 0) {
                    messageCenterTab.badgeValue = String(MessageCenter.shared.messageList.unreadCount)
                } else {
                    messageCenterTab.badgeValue = nil
                }
            }
        }
    }
    
    // MARK Deep link handling
    
    // Available Deep Links:
    //    - <scheme>://deeplink/home
    //    - <scheme>://deeplink/inbox
    //    - <scheme>://deeplink/inbox/message/<messageId>
    //    - <scheme>://deeplink/settings
    //    - <scheme>://deeplink/settings/tags

    func receivedDeepLink(_ url: URL, completionHandler: @escaping () -> ()) {
        // if the deep link is an http or https URL, open it in the browser
        if (url.scheme == "http" || url.scheme == "https") {
            DispatchQueue.main.async {
                UIApplication.shared.open(url, options: [:], completionHandler: nil);
            };
            completionHandler()
            return;
        }
        
        var pathComponents = url.pathComponents
        if (pathComponents.count == 0) {
            completionHandler()
            return;
        }

        if (pathComponents[0] == "/") {
            pathComponents.remove(at: 0)
        }

        let tabController = window!.rootViewController as! UITabBarController

        // map existing deep links to new paths
        switch (pathComponents[0].lowercased()) {
            #if DEBUG
        case InAppAutomationStoryboardID:
            pathComponents = [ DebugStoryboardID, AirshipDebug.automationViewName ]
            #endif
        default:
            break
        }
        
        // map deeplinks to storyboards paths
        switch (pathComponents[0].lowercased()) {
        case "home":
            pathComponents[0] = HomeStoryboardID
        case "inbox":
            pathComponents[0] = MessageCenterStoryboardID
        case "settings":
            pathComponents[0] = SettingsStoryboardID
        default:
            break
        }

        // execute deep link
        switch (pathComponents[0].lowercased()) {
        case HomeStoryboardID:
            // switch to home tab
            tabController.selectedIndex = HomeTab
        case MessageCenterStoryboardID:
            // switch to inbox tab
            tabController.selectedIndex = MessageCenterTab

            // get rest of deep link
            pathComponents.remove(at: 0)
            
            if ((pathComponents.count == 0) || (pathComponents[0] != "message")) {
                MessageCenter.shared.display()
            } else {
                // remove "message" from front of url
                pathComponents.remove(at: 0)
                var messageID = ""
                if (pathComponents.count > 0) {
                    messageID = pathComponents[0]
                }
                MessageCenter.shared.displayMessage(forID: messageID)
            }
        case SettingsStoryboardID:
            // get rest of deep link
            pathComponents.remove(at: 0)

            guard let settingsNavController = tabController.viewControllers?[SettingsTab] as? UINavigationController else { break }
            guard let settingsViewController = settingsNavController.viewControllers[0] as? SettingsViewController else { break }
            settingsViewController.launchPathComponents = pathComponents
            
            // switch to settings tab if necessary
            if (tabController.selectedIndex != SettingsTab) {
                tabController.selectedIndex = SettingsTab;
            }
        case DebugStoryboardID:
            #if DEBUG
            // switch to debug tab
            tabController.selectedIndex = DebugTab

            // get rest of deep link
            pathComponents.remove(at: 0)
            AirshipDebug.showView(pathComponents)
            #endif
            break
        default:
            break
        }
 
        completionHandler()
    }

    // MARK: UAInAppMessageCachePolicyDelegate
    func shouldCache(onSchedule message: InAppMessage) -> Bool {
        return true
    }
    
    func shouldPersistCache(afterDisplay message: InAppMessage) -> Bool {
        return true
    }
}


