/* Copyright Airship and Contributors */

import Foundation
import UserNotifications
import UIKit
/**
 * Internal protocol to fan out push handling to UAComponents.
 *  - Note: For internal use only. :nodoc:
 */
@objc(UAPushableComponent)
public protocol PushableComponent: AnyObject {
    #if !os(watchOS)
    /**
     * Called when a remote notification is received.
     *  - Parameters:
     *    - notification: The notification.
     *    - completionHandler: The completion handler that must be called with the fetch result.
     */
    @objc
    optional func receivedRemoteNotification(_ notification: [AnyHashable: Any], completionHandler: @escaping (UIBackgroundFetchResult) -> Void)
    #else
    /**
     * Called when a remote notification is received.
     *  - Parameters:
     *    - notification: The notification.
     *    - completionHandler: The completion handler that must be called with the fetch result.
     */
    @objc
    optional func receivedRemoteNotification(_ notification: [AnyHashable: Any], completionHandler: @escaping (WKBackgroundFetchResult) -> Void)
    #endif

    #if !os(tvOS)
    /**
     * Called when a notification response is received.
     * - Parameters:
     *   - response: The notification response.
     *   - completionHandler: The completion handler that must be called after processing the response.
     */
    @objc
    optional func receivedNotificationResponse(_ response: UNNotificationResponse, completionHandler: @escaping () -> Void)
    #endif

    /**
     * Called when a notification is about to be presented.
     * - Returns: The presentation options.
     * - Parameters:
     *   - notification: The notification to be presented.
     *   - options: Default presentation options.
     */
    @objc(presentationOptionsForNotification:defaultPresentationOptions:)
    optional func presentationOptions(for notification: UNNotification, defaultPresentationOptions options: UNNotificationPresentationOptions) -> UNNotificationPresentationOptions
}
