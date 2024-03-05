/* Copyright Airship and Contributors */


import Foundation

protocol AirshipUserNotificationCenterProtocol {
    func setBadgeNumber(_ newBadgeNumber: Int) async throws
}


/// - Note: For internal use only. :nodoc:
public struct AirshipUserNotificationCenter: @unchecked Sendable, AirshipUserNotificationCenterProtocol {
    public static let shared = AirshipUserNotificationCenter()

    public func setBadgeNumber(_ newBadgeNumber: Int) async throws {
        #if !os(watchOS)
        if #available(iOS 16.0, tvOS 16.0, visionOS 1.0, *) {
            try await UNUserNotificationCenter.current().setBadgeCount(newBadgeNumber)
        } else {
            AirshipLogger.debug("Set badge number should not be called on AirshipUserNotificationCenterProtocol implementation before iOS 16")
        }
        #endif
    }
}
