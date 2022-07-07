/* Copyright Airship and Contributors */

import Foundation
#if os(watchOS)
import WatchKit
#endif

/// Protocol to be implemented by push notification clients. All methods are optional.
@objc(UAPushNotificationDelegate)
public protocol PushNotificationDelegate: NSObjectProtocol {
    /// Called when a notification is received in the foreground.
    ///
    /// - Parameters:
    ///   - userInfo: The notification info
    ///   - completionHandler: the completion handler to execute when notification processing is complete.
    @objc
    optional func receivedForegroundNotification(_ userInfo: [AnyHashable : Any], completionHandler: @escaping () -> Void)
#if !os(watchOS)
    /// Called when a notification is received in the background.
    ///
    /// - Parameters:
    ///   - userInfo: The notification info
    ///   - completionHandler: the completion handler to execute when notification processing is complete.
    @objc
    optional func receivedBackgroundNotification(_ userInfo: [AnyHashable : Any], completionHandler: @escaping (UIBackgroundFetchResult) -> Void)
#else
    /// Called when a notification is received in the background.
    ///
    /// - Parameters:
    ///   - userInfo: The notification info
    ///   - completionHandler: the completion handler to execute when notification processing is complete.
    @objc
    optional func receivedBackgroundNotification(_ userInfo: [AnyHashable : Any], completionHandler: @escaping (WKBackgroundFetchResult) -> Void)
#endif
#if !os(tvOS)
    /// Called when a notification is received in the background or foreground and results in a user interaction.
    /// User interactions can include launching the application from the push, or using an interactive control on the notification interface
    /// such as a button or text field.
    ///
    /// - Parameters:
    ///   - notificationResponse: UNNotificationResponse object representing the user's response
    /// to the notification and the associated notification contents.
    ///
    ///   - completionHandler: the completion handler to execute when processing the user's response has completed.
    @objc
    optional func receivedNotificationResponse(_ notificationResponse: UNNotificationResponse, completionHandler: @escaping () -> Void)
#endif
    /// Called when a notification has arrived in the foreground and is available for display.
    ///
    /// - Parameters:
    ///   - options: The notification presentation options.
    ///   - notification: The notification.
    /// - Returns: a UNNotificationPresentationOptions enum value indicating the presentation options for the notification.
    @objc(extendPresentationOptions:notification:)
    optional func extend(_ options: UNNotificationPresentationOptions, notification: UNNotification) -> UNNotificationPresentationOptions
}
