/* Copyright Airship and Contributors */

import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(WatchKit)
import WatchKit
#endif
public import UserNotifications

public enum UABackgroundFetchResult : Sendable {
    case newData
    case noData
    case failed

    /// Merges two fetch results.
    /// Logic: .newData always wins. .failed wins over .noData to ensure the system
    /// knows an error occurred even if other components had no data.
    public func merge(_ other: UABackgroundFetchResult) -> UABackgroundFetchResult {
        switch (self, other) {
        case (.newData, _), (_, .newData):
            return .newData
        case (.failed, _), (_, .failed):
            return .failed
        default:
            return .noData
        }
    }

    /// Merges a collection of fetch results into a single result.
    public static func merged(_ results: [UABackgroundFetchResult]) -> UABackgroundFetchResult {
        return results.reduce(.noData) { $0.merge($1) }
    }

#if !os(watchOS) && !os(macOS)
    var osFetchResult: UIBackgroundFetchResult {
        return switch(self) {
        case .newData: .newData
        case .noData: .noData
        case .failed: .failed
        }
    }

    init(from osResult: UIBackgroundFetchResult) {
        self = switch(osResult) {
        case .newData: .newData
        case .noData: .noData
        case .failed: .failed
        @unknown default: .noData
        }
    }
#elseif os(watchOS)
    var osFetchResult: WKBackgroundFetchResult {
        return switch(self) {
        case .newData: .newData
        case .noData: .noData
        case .failed: .failed
        }
    }

    init(from osResult: WKBackgroundFetchResult) {
        self = switch(osResult) {
        case .newData: .newData
        case .noData: .noData
        case .failed: .failed
        @unknown default: .noData
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
