/* Copyright Urban Airship and Contributors */

import AirshipCore
import WatchKit

class ExtensionDelegate: NSObject, WKExtensionDelegate, DeepLinkDelegate {

    func applicationDidFinishLaunching() {

        // Populate AirshipConfig.plist with your app's info from https://go.urbanairship.com
        // or set runtime properties here.
        var config = try! AirshipConfig.default()
        config.productionLogLevel = .verbose
        config.developmentLogLevel = .verbose

        // Set log level for debugging config loading (optional)
        // It will be set to the value in the loaded config upon takeOff
        config.productionLogLevel = .verbose
        config.developmentLogLevel = .verbose

        // Print out the application configuration for debugging (optional)
        print("Config:\n \(config)")

        // You can then programmatically override the plist values:
        // config.developmentAppKey = "YourKey"
        // etc.

        // Call takeOff (which creates the UAirship singleton)
        try? Airship.takeOff(config)

        Airship.channel.editTags { $0.add(["watchOs"]) }
        Airship.deepLinkDelegate = self

        // User notifications will not be enabled until userPushNotificationsEnabled is
        // enabled on UAPush. Once enabled, the setting will be persisted and the user
        // will be prompted to allow notifications. You should wait for a more appropriate
        // time to enable push to increase the likelihood that the user will accept
        // notifications.

        Airship.push.notificationOptions = [.alert, .sound, .badge]
    }

    func applicationDidBecomeActive() {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillResignActive() {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, etc.
    }
    
    func receivedDeepLink(_ deepLink: URL) async {
        // Handle deeplink navigation
        print("deeplink received: \(deepLink)")
    }
}
