/* Copyright Airship and Contributors */

import Foundation
import UserNotifications

#if canImport(UIKit)
import UIKit
#endif

#if canImport(WatchKit)
import WatchKit
#endif

/// Delegate for Airship auto-integration events.
protocol AppIntegrationDelegate: AnyObject, Sendable {
    @MainActor
    func didRegisterForRemoteNotifications(deviceToken: Data)
    
    @MainActor
    func didFailToRegisterForRemoteNotifications(error: any Error)
    
    @MainActor
    func onBackgroundAppRefresh()
    
    @MainActor
    func presentationOptions(for notification: UNNotification, completionHandler: @Sendable @escaping (UNNotificationPresentationOptions) -> Void)
    
    @MainActor
    func willPresentNotification(notification: UNNotification, presentationOptions: UNNotificationPresentationOptions, completionHandler: @Sendable @escaping () -> Void)
    
#if !os(tvOS)
    @MainActor
    func didReceiveNotificationResponse(response: UNNotificationResponse, completionHandler: @Sendable @escaping () -> Void)
#endif
    
#if os(watchOS)
    @MainActor
    func didReceiveRemoteNotification(userInfo: [AnyHashable: Any], isForeground: Bool, completionHandler: @Sendable @escaping (WKBackgroundFetchResult) -> Void)
#elseif os(macOS)
    @MainActor
    func didReceiveRemoteNotification(userInfo: [AnyHashable: Any], isForeground: Bool)
#else
    @MainActor
    func didReceiveRemoteNotification(userInfo: [AnyHashable: Any], isForeground: Bool, completionHandler: @Sendable @escaping (UIBackgroundFetchResult) -> Void)
#endif
}
