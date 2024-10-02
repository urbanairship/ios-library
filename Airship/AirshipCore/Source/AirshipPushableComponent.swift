/* Copyright Airship and Contributors */

import Foundation
import UIKit
import UserNotifications

/// Internal protocol to fan out push handling to UAComponents.
///  - Note: For internal use only. :nodoc:
public protocol AirshipPushableComponent {
    #if !os(watchOS)
    /**
     * Called when a remote notification is received.
     *  - Parameters:
     *    - notification: The notification.
     *    - completionHandler: The completion handler that must be called with the fetch result.
     */
    @MainActor
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
    @MainActor
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
    @MainActor
    func receivedNotificationResponse(
        _ response: UNNotificationResponse,
        completionHandler: @escaping () -> Void
    )
    #endif
}

extension AirshipPushableComponent {
#if !os(watchOS)
    @MainActor
    public func receivedRemoteNotification(
        _ notification: [AnyHashable: Any],
        completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        completionHandler(.noData)
    }
#else

    @MainActor
    public func receivedRemoteNotification(
        _ notification: [AnyHashable: Any],
        completionHandler: @escaping (WKBackgroundFetchResult) -> Void
    ) {
        completionHandler(.noData)
    }
#endif

#if !os(tvOS)

    @MainActor
    public func receivedNotificationResponse(
        _ response: UNNotificationResponse,
        completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
#endif
}
