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

    #if !os(tvOS)
    /**
     * Must be called by the UNUserNotificationDelegate's
     * userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler.
     *
     * - Parameters:
     *   - center: The notification center.
     *   - response: The notification response.
     */
    @MainActor
    public class func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async  {
        guard let delegate = integrationDelegate else {
            logIgnoringCall()
            return
        }

        await delegate.didReceiveNotificationResponse(
            response: response
        )
    }
    #endif
}
