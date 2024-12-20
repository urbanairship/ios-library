/* Copyright Airship and Contributors */

import Foundation

#if canImport(WatchKit)
import WatchKit
#endif

#if canImport(UIKit)
import UIKit
#endif

import UserNotifications

/// Protocol to be implemented by push notification clients. All methods are optional.
public protocol PushNotificationDelegate: AnyObject, Sendable {
    /// Called when a notification is received in the foreground.
    ///
    /// - Parameters:
    ///   - userInfo: The notification info
    @MainActor
    func receivedForegroundNotification(_ userInfo: [AnyHashable: Any]) async
    #if !os(watchOS)
    /// Called when a notification is received in the background.
    ///
    /// - Parameters:
    ///   - userInfo: The notification info
    @MainActor
    func receivedBackgroundNotification(_ userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult
    #else
    /// Called when a notification is received in the background.
    ///
    /// - Parameters:
    ///   - userInfo: The notification info
    @MainActor
    func receivedBackgroundNotification(_ userInfo: [AnyHashable: Any]) async -> WKBackgroundFetchResult
    #endif
    #if !os(tvOS)
    /// Called when a notification is received in the background or foreground and results in a user interaction.
    /// User interactions can include launching the application from the push, or using an interactive control on the notification interface
    /// such as a button or text field.
    ///
    /// - Parameters:
    ///   - notificationResponse: UNNotificationResponse object representing the user's response
    /// to the notification and the associated notification contents.
    func receivedNotificationResponse(_ notificationResponse: UNNotificationResponse) async
    #endif
    
    /// Called when a notification has arrived in the foreground and is available for display.
    ///
    /// - Parameters:
    ///   - options: The notification presentation options.
    ///   - notification: The notification.
    func extendPresentationOptions(
        _ options: UNNotificationPresentationOptions,
        notification: UNNotification
    ) async -> UNNotificationPresentationOptions
}

public extension PushNotificationDelegate {
    func extendPresentationOptions(
        _ options: UNNotificationPresentationOptions,
        notification: UNNotification) async -> UNNotificationPresentationOptions {
            
        return []
    }

    func receivedForegroundNotification(_ userInfo: [AnyHashable: Any]) async {
    }

    #if !os(watchOS)
    func receivedBackgroundNotification(_ userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        return .noData
    }
    
    #else
    func receivedBackgroundNotification(_ userInfo: [AnyHashable: Any]) async -> WKBackgroundFetchResult {
        return .noData
    }
    #endif

    #if !os(tvOS)
    func receivedNotificationResponse(_ notificationResponse: UNNotificationResponse) async {
    }
    #endif
}
