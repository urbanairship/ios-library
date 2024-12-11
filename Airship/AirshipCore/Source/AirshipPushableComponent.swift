/* Copyright Airship and Contributors */

import Foundation
import UIKit
import UserNotifications

/// Internal protocol to fan out push handling to UAComponents.
///  - Note: For internal use only. :nodoc:
public protocol AirshipPushableComponent: Sendable {
    #if !os(watchOS)
    /**
     * Called when a remote notification is received.
     *  - Parameters:
     *    - notification: The notification.
     */
    @MainActor
    func receivedRemoteNotification(
        _ notification: AirshipJSON // wrapped [AnyHashable: Any]
    ) async -> UIBackgroundFetchResult
    #else
    /**
     * Called when a remote notification is received.
     *  - Parameters:
     *    - notification: The notification.
     */
    @MainActor
    func receivedRemoteNotification(
        _ notification: AirshipJSON // wrapped [AnyHashable: Any]
    ) async -> WKBackgroundFetchResult
    #endif

    #if !os(tvOS)
    /**
     * Called when a notification response is received.
     * - Parameters:
     *   - response: The notification response.
     *   - completionHandler: The completion handler that must be called after processing the response.
     */
    @MainActor
    func receivedNotificationResponse(_ response: UNNotificationResponse) async
    #endif
}

extension AirshipPushableComponent {
#if !os(watchOS)
    @MainActor
    public func receivedRemoteNotification(_ notification: AirshipJSON) async -> UIBackgroundFetchResult {
        return .noData
    }
#else

    @MainActor
    public func receivedRemoteNotification(_ notification: AirshipJSON) async -> WKBackgroundFetchResult {
        return .noData
    }
#endif

#if !os(tvOS)
    @MainActor
    public func receivedNotificationResponse(_ response: UNNotificationResponse) async {
    }
#endif
}
