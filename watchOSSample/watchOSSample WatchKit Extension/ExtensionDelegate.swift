/* Copyright Airship and Contributors */

import AirshipCore
import WatchKit

class ExtensionDelegate: NSObject, WKExtensionDelegate {

    func applicationDidFinishLaunching() {

        // Populate AirshipConfig.plist with your app's info from https://go.urbanairship.com
        // or set runtime properties here.
        let config = Config.default()
        config.developmentLogLevel = LogLevel.trace

        // Set log level for debugging config loading (optional)
        // It will be set to the value in the loaded config upon takeOff
        Airship.logLevel = LogLevel.trace

        // Print out the application configuration for debugging (optional)
        print("Config:\n \(config)")

        // You can then programmatically override the plist values:
        // config.developmentAppKey = "YourKey"
        // etc.

        // Call takeOff (which creates the UAirship singleton)
        Airship.takeOff(config)

        // Print out the application configuration for debugging (optional)
        print("Config:\n \(config)")

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

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        // Sent when the system needs to launch the application in the background to process tasks. Tasks arrive in a set, so loop through and process each one.
        for task in backgroundTasks {
            // Use a switch statement to check the task type
            switch task {
            case let backgroundTask as WKApplicationRefreshBackgroundTask:
                // Be sure to complete the background task once you’re done.
                backgroundTask.setTaskCompletedWithSnapshot(false)
            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
                // Snapshot tasks have a unique completion call, make sure to set your expiration date
                snapshotTask.setTaskCompleted(
                    restoredDefaultState: true,
                    estimatedSnapshotExpiration: Date.distantFuture,
                    userInfo: nil
                )
            case let connectivityTask
                as WKWatchConnectivityRefreshBackgroundTask:
                // Be sure to complete the connectivity task once you’re done.
                connectivityTask.setTaskCompletedWithSnapshot(false)
            case let urlSessionTask as WKURLSessionRefreshBackgroundTask:
                // Be sure to complete the URL session task once you’re done.
                urlSessionTask.setTaskCompletedWithSnapshot(false)
            case let relevantShortcutTask
                as WKRelevantShortcutRefreshBackgroundTask:
                // Be sure to complete the relevant-shortcut task once you're done.
                relevantShortcutTask.setTaskCompletedWithSnapshot(false)
            case let intentDidRunTask as WKIntentDidRunRefreshBackgroundTask:
                // Be sure to complete the intent-did-run task once you're done.
                intentDidRunTask.setTaskCompletedWithSnapshot(false)
            default:
                // make sure to complete unhandled task types
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }
}
