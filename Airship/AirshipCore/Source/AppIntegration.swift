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
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @Sendable @escaping (
            UIBackgroundFetchResult
        ) -> Void
    ) {

        guard let delegate = integrationDelegate else {
            logIgnoringCall()
            completionHandler(.noData)
            return
        }

        let isForeground = application.applicationState == .active
        delegate.didReceiveRemoteNotification(
            userInfo: userInfo,
            isForeground: isForeground,
            completionHandler: completionHandler
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
        userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @Sendable @escaping (
            WKBackgroundFetchResult
        ) -> Void
    ) {

        guard let delegate = integrationDelegate else {
            logIgnoringCall()
            completionHandler(.noData)
            return
        }

        let isForeground = WKExtension.shared().applicationState == .active
        delegate.didReceiveRemoteNotification(
            userInfo: userInfo,
            isForeground: isForeground,
            completionHandler: completionHandler
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
     *   - completionHandler: The completion handler.
     */
    @MainActor
    public class func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @Sendable @escaping (
            _ options: UNNotificationPresentationOptions
        ) -> Void
    ) {
        guard let delegate = integrationDelegate else {
            logIgnoringCall()
            completionHandler([])
            return
        }
        
        delegate.presentationOptionsForNotification(notification) { presentationOptions in
            delegate.willPresentNotification(
                notification: notification,
                presentationOptions: presentationOptions
            ) {
                completionHandler(presentationOptions)
            }
        }
    }

    #if !os(tvOS)
    /**
     * Must be called by the UNUserNotificationDelegate's
     * userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler.
     *
     * - Parameters:
     *   - center: The notification center.
     *   - response: The notification response.
     *   - completionHandler: The completion handler.
     */
    @MainActor
    public class func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @Sendable @escaping () -> Void
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
