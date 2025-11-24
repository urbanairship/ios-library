/* Copyright Airship and Contributors */

#if canImport(UIKit)
import UIKit
#endif

#if canImport(WatchKit)
import WatchKit
#endif

#if canImport(AirshipBasement)
import AirshipBasement
#endif

import Foundation
@preconcurrency
import UserNotifications


/// Application hooks required by Airship. If `automaticSetupEnabled` is enabled
/// (enabled by default), Airship will automatically integrate these calls into
/// the application by swizzling methods. If `automaticSetupEnabled` is disabled,
/// the application must call through to every method provided by this class.
public class AppIntegration {

    /// - Note: For internal use only. :nodoc:
    @MainActor
    public static var integrationDelegate: (any AppIntegrationDelegate)?

    private class func logIgnoringCall(_ method: String = #function) {
        AirshipLogger.impError(
            "Ignoring call to \(method). Either takeOff is not called or automatic integration is enabled."
        )
    }

#if !os(watchOS)

    /**
     * Must be called by the UIApplicationDelegate's
     * application:performFetchWithCompletionHandler:.
     *
     * - Parameters:
     *   - application: The application
     *   - completionHandler: The completion handler.
     */
    @MainActor
    public class func application(
        _ application: UIApplication,
        performFetchWithCompletionHandler completionHandler: @escaping (
            UIBackgroundFetchResult
        ) -> Void
    ) {
        guard let delegate = integrationDelegate else {
            logIgnoringCall()
            completionHandler(.noData)
            return
        }

        delegate.onBackgroundAppRefresh()
        completionHandler(.noData)
    }

    /**
     * Must be called by the UIApplicationDelegate's
     * application:didRegisterForRemoteNotificationsWithDeviceToken:.
     *
     * - Parameters:
     *   - application: The application
     *   - deviceToken: The device token.
     */
    @MainActor
    public class func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        guard let delegate = integrationDelegate else {
            logIgnoringCall()
            return
        }

        delegate.didRegisterForRemoteNotifications(deviceToken: deviceToken)
    }

    /**
     * Must be called by the UIApplicationDelegate's
     * application:didFailToRegisterForRemoteNotificationsWithError:.
     *
     * - Parameters:
     *   - application: The application
     *   - error: The error.
     */
    @MainActor
    public class func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: any Error
    ) {
        guard let delegate = integrationDelegate else {
            logIgnoringCall()
            return
        }

        delegate.didFailToRegisterForRemoteNotifications(error: error)
    }

    /**
     * Must be called by the UIApplicationDelegate's
     * application:didReceiveRemoteNotification:fetchCompletionHandler:.
     *
     * - Parameters:
     *   - application: The application
     *   - userInfo: The remote notification.
     *   - completionHandler: The completion handler.
     */
    @MainActor
    public class func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any]
    ) async -> UIBackgroundFetchResult {

        guard let delegate = integrationDelegate else {
            logIgnoringCall()
            return .noData
        }

        let isForeground = application.applicationState == .active
        return await delegate.didReceiveRemoteNotification(
            userInfo: userInfo,
            isForeground: isForeground
        )
    }
#else
    /**
     * Must be called by the WKExtensionDelegate's
     * didRegisterForRemoteNotificationsWithDeviceToken:.
     *
     * - Parameters:
     *   - deviceToken: The device token.
     */
    @MainActor
    public class func didRegisterForRemoteNotificationsWithDeviceToken(
        deviceToken: Data
    ) {
        guard let delegate = integrationDelegate else {
            logIgnoringCall()
            return
        }

        delegate.didRegisterForRemoteNotifications(deviceToken: deviceToken)
    }

    /**
     * Must be called by the WKExtensionDelegate's
     * didFailToRegisterForRemoteNotificationsWithError:.
     *
     * - Parameters:
     *   - error: The error.
     */
    @MainActor
    public class func didFailToRegisterForRemoteNotificationsWithError(
        error: any Error
    ) {
        guard let delegate = integrationDelegate else {
            logIgnoringCall()
            return
        }

        delegate.didFailToRegisterForRemoteNotifications(error: error)
    }
    /**
     * Must be called by the WKExtensionDelegate's
     * didReceiveRemoteNotification:fetchCompletionHandler:.
     *
     * - Parameters:
     *   - userInfo: The remote notification.
     *   - completionHandler: The completion handler.
     */
    @MainActor
    public class func didReceiveRemoteNotification(
        userInfo: [AnyHashable: Any]
    ) async -> WKBackgroundFetchResult {

        guard let delegate = integrationDelegate else {
            logIgnoringCall()
            return .noData
        }

        let isForeground = WKExtension.shared().applicationState == .active
        return await delegate.didReceiveRemoteNotification(
            userInfo: userInfo,
            isForeground: isForeground
        )
    }
#endif

    /**
     * Must be called by the UNUserNotificationDelegate's
     * userNotificationCenter:willPresentNotification:withCompletionHandler.
     *
     * - Parameters:
     *   - center: The notification center.
     *   - notification: The notification.
     */
    @MainActor
    public class func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        guard let delegate = integrationDelegate else {
            logIgnoringCall()
            return []
        }
        
        let presentationOptions = await delegate.presentationOptionsForNotification(notification)
        await delegate.willPresentNotification(notification: notification, presentationOptions: presentationOptions)
        return presentationOptions
    }

    /**
     * Must be called by the UNUserNotificationDelegate's
     * userNotificationCenter:willPresentNotification:withCompletionHandler.
     *
     * - Parameters:
     *   - center: The notification center.
     *   - notification: The notification.
     *   - completionHandler: The completion handler.
     */
    @MainActor
    public class func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping @Sendable (UNNotificationPresentationOptions) -> Void
    ) {
        // This one does not depend on any lifecycle events so we can just do the async underneath
        Task { @MainActor in
            let options = await self.userNotificationCenter(center, willPresent: notification)
            completionHandler(options)
        }
    }


    #if !os(tvOS)
    /**
     * Processes a user's response to a notification.
     *
     * - Warning: ⚠️ **Deprecated**. This asynchronous method is deprecated and will be removed in a future release.
     * It can cause critical application lifecycle issues due to changes in how Apple's modern User Notification
     * delegates operate.
     *
     * ### Lifecycle Issues Explained
     *
     * Apple's modern `async` notification delegate methods execute on a **background thread** by default instead of a the main
     * thread. This creates a race condition during app launch:
     *
     * 1.  **Main Thread:** Proceeds with the standard launch sequence, making the app's UI active and visible.
     * 2.  **Background Thread:** Runs this notification code. By the time it can switch back to the main
     * thread, the app is often already active.
     *
     * This breaks the critical assumption that code for a "direct open" notification runs *before* the app is fully
     * interactive. This can lead to incorrect direct open counts.
     *
     * ### Migration
     *
     * To fix this, you must migrate to the synchronous version of this method, which accepts and forwards a `completionHandler`.
     * This guarantees your code runs on the main thread at the correct point in the lifecycle, before the app becomes active.
     *
     * - SeeAlso: `userNotificationCenter(_:didReceive:withCompletionHandler:)`

     * - Parameters:
     * - center: The notification center that delivered the notification.
     * - response: The user's response to the notification.
     */
    @available(*, deprecated, message: "Use the synchronous version with a completionHandler to avoid lifecycle issues.")
    @MainActor
    public class func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let delegate = integrationDelegate else {
            logIgnoringCall()
            return
        }

        await delegate.didReceiveNotificationResponse(
            response: response
        )
    }

    /**
     * Must be called by the UNUserNotificationDelegate's
     * userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler.
     *
     * - Parameters:
     *   - center: The notification center.
     *   - response: The notification response.
     *   - completionHandler: The completion handler
     */
    @MainActor
    public class func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping @Sendable () -> Void
    ) {
        guard let delegate = integrationDelegate else {
            logIgnoringCall()
            completionHandler()
            return
        }

        delegate.didReceiveNotificationResponse(
            response: response,
            completionHandler: completionHandler
        )
    }
    #endif
}
