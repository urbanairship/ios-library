/* Copyright Airship and Contributors */

import Foundation
public import AirshipCore

/// Protocol to be implemented by push notification clients. All methods are optional.
@objc
public protocol UAPushNotificationDelegate {
    /// Called when a notification is received in the foreground.
    ///
    /// - Parameters:
    ///   - userInfo: The notification info
    ///   - completionHandler: the completion handler to execute when notification processing is complete.
    @objc
    func receivedForegroundNotification(
        _ userInfo: [AnyHashable: Any],
        completionHandler: @escaping () -> Void
    )
    #if !os(watchOS)
    /// Called when a notification is received in the background.
    ///
    /// - Parameters:
    ///   - userInfo: The notification info
    ///   - completionHandler: the completion handler to execute when notification processing is complete.
    @objc
    func receivedBackgroundNotification(
        _ userInfo: [AnyHashable: Any],
        completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    )
    #else
    /// Called when a notification is received in the background.
    ///
    /// - Parameters:
    ///   - userInfo: The notification info
    ///   - completionHandler: the completion handler to execute when notification processing is complete.
    @objc
    func receivedBackgroundNotification(
        _ userInfo: [AnyHashable: Any],
        completionHandler: @escaping (WKBackgroundFetchResult) -> Void
    )
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
    func receivedNotificationResponse(
        _ notificationResponse: UNNotificationResponse,
        completionHandler: @escaping () -> Void
    )
    #endif
    /// Called when a notification has arrived in the foreground and is available for display.
    ///
    /// - Parameters:
    ///   - options: The notification presentation options.
    ///   - notification: The notification.
    /// - Returns: a UNNotificationPresentationOptions enum value indicating the presentation options for the notification.
    @objc(extendPresentationOptions:notification:)
    func extend(
        _ options: UNNotificationPresentationOptions,
        notification: UNNotification
    ) -> UNNotificationPresentationOptions

    
    /// Called when a notification has arrived in the foreground and is available for display.
    ///
    /// - Parameters:
    ///   - options: The notification presentation options.
    ///   - notification: The notification.
    ///   - completionHandler: The completion handler.
    @objc(extendPresentationOptions:notification:completionHandler:)
    func extendPresentationOptions(
        _ options: UNNotificationPresentationOptions,
        notification: UNNotification,
        completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    )
}

public class UAPushNotificationDelegateWrapper: NSObject, PushNotificationDelegate {
    private let delegate: UAPushNotificationDelegate
    
    init(delegate: UAPushNotificationDelegate) {
        self.delegate = delegate
    }
    
    public func receivedForegroundNotification(
        _ userInfo: [AnyHashable: Any],
        completionHandler: @escaping () -> Void
    ) {
        self.delegate.receivedForegroundNotification(userInfo, completionHandler: completionHandler)
    }
    
    #if !os(watchOS)
    
    public func receivedBackgroundNotification(
       _ userInfo: [AnyHashable: Any],
       completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        self.delegate.receivedBackgroundNotification(userInfo, completionHandler: completionHandler)
    }
    
    #else
    
    public func receivedBackgroundNotification(
        _ userInfo: [AnyHashable: Any],
        completionHandler: @escaping (WKBackgroundFetchResult) -> Void
    ) {
        self.delegate.receivedBackgroundNotification(userInfo, completionHandler: completionHandler)
    }
    
    #endif
    #if !os(tvOS)
    
    public func receivedNotificationResponse(
       _ notificationResponse: UNNotificationResponse,
       completionHandler: @escaping () -> Void
    ) {
        self.delegate.receivedNotificationResponse(notificationResponse, completionHandler: completionHandler)
    }
    
    #endif
    
    public func extend(
        _ options: UNNotificationPresentationOptions,
        notification: UNNotification
    ) -> UNNotificationPresentationOptions {
        return self.delegate.extend(options, notification: notification)
    }
    
    
    public func extendPresentationOptions(
        _ options: UNNotificationPresentationOptions,
        notification: UNNotification,
        completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        self.delegate.extendPresentationOptions(options, notification: notification, completionHandler: completionHandler)
    }
}
