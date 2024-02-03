/* Copyright Airship and Contributors */

import Foundation
import UIKit
import UserNotifications

/// Internal protocol to fan out push handling to UAComponents.
///  - Note: For internal use only. :nodoc:
public protocol PushableComponent: AnyObject {
    #if !os(watchOS)
    /**
     * Called when a remote notification is received.
     *  - Parameters:
     *    - notification: The notification.
     *    - completionHandler: The completion handler that must be called with the fetch result.
     */
    func receivedRemoteNotification(
        _ notification: [AnyHashable: Any],
        completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    )
    #else
    /**
     * Called when a remote notification is received.
     *  - Parameters:
     *    - notification: The notification.
     *    - completionHandler: The completion handler that must be called with the fetch result.
     */
    func receivedRemoteNotification(
        _ notification: [AnyHashable: Any],
        completionHandler: @escaping (WKBackgroundFetchResult) -> Void
    )
    #endif

    #if !os(tvOS)
    /**
     * Called when a notification response is received.
     * - Parameters:
     *   - response: The notification response.
     *   - completionHandler: The completion handler that must be called after processing the response.
     */
    func receivedNotificationResponse(
        _ response: UNNotificationResponse,
        completionHandler: @escaping () -> Void
    )
    #endif
}

extension PushableComponent {
#if !os(watchOS)
    public func receivedRemoteNotification(
        _ notification: [AnyHashable: Any],
        completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        completionHandler(.noData)
    }
#else

    public func receivedRemoteNotification(
        _ notification: [AnyHashable: Any],
        completionHandler: @escaping (WKBackgroundFetchResult) -> Void
    ) {
        completionHandler(.noData)
    }
#endif

#if !os(tvOS)

    public func receivedNotificationResponse(
        _ response: UNNotificationResponse,
        completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
#endif
}
