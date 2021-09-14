/* Copyright Airship and Contributors */

/**
 * Application hooks required by Airship. If `automaticSetupEnabled` is enabled
 * (enabled by default), Airship will automatically integrate these calls into
 * the application by swizzling methods. If `automaticSetupEnabled` is disabled,
 * the application must call through to every method provided by this class.
 */
@objc(UAAppIntegration)
public class AppIntegration : NSObject {
    
    /// - Note: For internal use only. :nodoc:
    @objc
    public static var integrationDelegate: AppIntegrationDelegate?
    
    private class func logIgnoringCall(_ method: String = #function) {
        AirshipLogger.impError("Ignoring call to \(method). Either takeOff is not called or automatic integration is enabled.")
    }
    
    /**
     * Must be called by the UIApplicationDelegate's
     * application:performFetchWithCompletionHandler:.
     *
     * - Parameters:
     *   - application: The application
     *   - completionHandler: The completion handler.
     */
    @objc(applicatin:performFetchWithCompletionHandler:)
    public class func application(_ application: UIApplication,
                                  performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
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
    @objc(application:didRegisterForRemoteNotificationsWithDeviceToken:)
    public class func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
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
    @objc
    public class func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
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
    @objc
    public class func application(_ application: UIApplication,
                                  didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                                  fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        guard let delegate = integrationDelegate else {
            logIgnoringCall()
            completionHandler(.noData)
            return
        }
        
        let isForeground = application.applicationState == .active
        delegate.didReceiveRemoteNotification(userInfo: userInfo, isForeground: isForeground, completionHandler: completionHandler);
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
    @objc
    public class func userNotificationCenter(center: UNUserNotificationCenter,
                                             willPresentNotification notification: UNNotification,
                                             withCompletionHandler completionHandler: @escaping (_ options: UNNotificationPresentationOptions) -> Void) {
        
        guard let delegate = integrationDelegate else {
            logIgnoringCall()
            completionHandler([])
            return
        }
        
        let options = delegate.presentationOptions(for: notification)
        delegate.willPresentNotification(notification: notification, presentationOptions: options) {
            completionHandler(options)
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
    @objc
    public class func userNotificationCenter(center: UNUserNotificationCenter,
                                             didReceiveNotificationResponse response: UNNotificationResponse,
                                             withCompletionHandler completionHandler: @escaping () -> Void) {
        guard let delegate = integrationDelegate else {
            logIgnoringCall()
            completionHandler()
            return
        }
        
        delegate.didReceiveNotificationResponse(response: response, completionHandler: completionHandler)
    }
    #endif
}

