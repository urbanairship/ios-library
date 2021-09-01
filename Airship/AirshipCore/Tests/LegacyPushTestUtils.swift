
import Foundation

@testable
import AirshipCore

/**
 * Exposes methods from the `InternalPushProtocol` to our legacy obj-c push tests.
 */
@objc
public class LegacyPushTestUtils : NSObject {
    @objc
    public class func setDeviceToken(push: Push, token: Data) {
        push.didRegisterForRemoteNotifications(token)
    }
    
    @objc
    public class func presentationOptions(push: Push, notification: UNNotification) -> UNNotificationPresentationOptions {
        return push.presentationOptionsForNotification(notification)
    }
    
    @objc
    public class func didReceiveNotificationResponse(push: Push, response: UNNotificationResponse, completionHandler: @escaping () -> Void) {
        push.didReceiveNotificationResponse(response, completionHandler: completionHandler)
    }
    
    @objc
    public class func didReceiveRemoteNotification(push: Push, userInfo: [AnyHashable : Any], isForeground: Bool, completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        push.didReceiveRemoteNotification(userInfo, isForeground: isForeground, completionHandler: completionHandler);
    }

    @objc
    public class func didFailToRegisterForRemoteNotifications(push: Push, error: Error) {
        push.didFailToRegisterForRemoteNotifications(error)
    }
    
    @objc
    public class func updateAuthorizedNotificationTypes(push: Push) {
        push.updateAuthorizedNotificationTypes()
    }
}
