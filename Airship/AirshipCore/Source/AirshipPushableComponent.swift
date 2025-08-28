/* Copyright Airship and Contributors */


import UIKit
import UserNotifications

public enum UABackgroundFetchResult : Sendable {
    case newData
    case noData
    case failed

#if !os(watchOS)
    var osFetchResult: UIBackgroundFetchResult {
        return switch(self) {
        case .newData: .newData
        case .noData: .noData
        case .failed: .failed
        }
    }
#else
    var osFetchResult: WKBackgroundFetchResult {
        return switch(self) {
        case .newData: .newData
        case .noData: .noData
        case .failed: .failed
        }
    }
#endif
}

/// Internal protocol to fan out push handling to UAComponents.
///  - Note: For internal use only. :nodoc:
public protocol AirshipPushableComponent: Sendable {
    /**
     * Called when a remote notification is received.
     *  - Parameters:
     *    - notification: The notification.
     */
    @MainActor
    func receivedRemoteNotification(
        _ notification: AirshipJSON // wrapped [AnyHashable: Any]
    ) async -> UABackgroundFetchResult

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
