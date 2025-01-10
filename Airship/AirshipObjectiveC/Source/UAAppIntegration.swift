/* Copyright Airship and Contributors */

public import Foundation

#if canImport(UIKit)
public import UIKit
#endif

#if canImport(AirshipCore)
import AirshipCore
#endif

@preconcurrency import UserNotifications

/// Application hooks required by Airship. If `automaticSetupEnabled` is enabled
/// (enabled by default), Airship will automatically integrate these calls into
/// the application by swizzling methods. If `automaticSetupEnabled` is disabled,
/// the application must call through to every method provided by this class.
@objc
@MainActor
public final class UAAppIntegration: NSObject {

#if !os(watchOS)
    
    /**
     * Must be called by the UIApplicationDelegate's
     * application:performFetchWithCompletionHandler:.
     *
     * - Parameters:
     *   - application: The application
     *   - completionHandler: The completion handler.
     */
    @objc(application:performFetchWithCompletionHandler:)
    public class func application(
        _ application: UIApplication,
        performFetchWithCompletionHandler completionHandler: @Sendable @escaping (
            UIBackgroundFetchResult
        ) -> Void
    ) {
        AppIntegration.application(application, performFetchWithCompletionHandler: completionHandler)
    }
    
    /**
     * Must be called by the UIApplicationDelegate's
     * application:didRegisterForRemoteNotificationsWithDeviceToken:.
     *
     * - Parameters:
     *   - application: The application
     *   - deviceToken: The device token.
     */
    @objc(application:didRegisterForRemoteNotificationsWithDeviceToken:)
    public class func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        AppIntegration.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }
    
    /**
     * Must be called by the UIApplicationDelegate's
     * application:didFailToRegisterForRemoteNotificationsWithError:.
     *
     * - Parameters:
     *   - application: The application
     *   - error: The error.
     */
    @objc
    public class func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: any Error
    ) {
        AppIntegration.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
    }
    
    /**
     * Must be called by the UIApplicationDelegate's
     * application:didReceiveRemoteNotification:fetchCompletionHandler:.
     *
     * - Parameters:
     *   - application: The application
     *   - userInfo: The remote notification.
     */
    @objc(application:didReceiveRemoteNotification:fetchCompletionHandler:)
    public class func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any]
    ) async -> UIBackgroundFetchResult  {
        return await AppIntegration.application(application, didReceiveRemoteNotification: userInfo)
    }
#else
    /**
     * Must be called by the WKExtensionDelegate's
     * didRegisterForRemoteNotificationsWithDeviceToken:.
     *
     * - Parameters:
     *   - deviceToken: The device token.
     */
    @objc(didRegisterForRemoteNotificationsWithDeviceToken:)
    public class func didRegisterForRemoteNotificationsWithDeviceToken(
        deviceToken: Data
    ) {
        AppIntegration.didRegisterForRemoteNotificationsWithDeviceToken(deviceToken)
    }
    
    /**
     * Must be called by the WKExtensionDelegate's
     * didFailToRegisterForRemoteNotificationsWithError:.
     *
     * - Parameters:
     *   - error: The error.
     */
    @objc
    public class func didFailToRegisterForRemoteNotificationsWithError(
        error: Error
    ) {
        AppIntegration.didFailToRegisterForRemoteNotificationsWithError(error)
    }
    
    /**
     * Must be called by the WKExtensionDelegate's
     * didReceiveRemoteNotification:fetchCompletionHandler:.
     *
     * - Parameters:
     *   - userInfo: The remote notification.
     */
    @objc(application:didReceiveRemoteNotification:fetchCompletionHandler:)
    public class func didReceiveRemoteNotification(
        userInfo: [AnyHashable: Any]
    ) async -> WKBackgroundFetchResult {
        return await AppIntegration.didReceiveRemoteNotification(userInfo: userInfo)
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
    @objc(userNotificationCenter:willPresentNotification:withCompletionHandler:)
    public class func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return await AppIntegration.userNotificationCenter(center, willPresent: notification)
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
    @objc(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:)
    public class func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await AppIntegration.userNotificationCenter(center, didReceive: response)
    }
#endif
}
