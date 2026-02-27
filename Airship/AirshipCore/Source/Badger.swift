/* Copyright Airship and Contributors */

import Foundation
import UserNotifications

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

protocol BadgerProtocol: AnyObject, Sendable {
    func setBadgeNumber(_ newBadgeNumber: Int) async throws

    @MainActor
    var badgeNumber: Int { get }
}

final class Badger: Sendable, BadgerProtocol {
    public static let shared: Badger = Badger()

    func setBadgeNumber(_ newBadgeNumber: Int) async throws {
#if os(watchOS)
        // watchOS does not support app icon badges
        return
#else
        AirshipLogger.debug("Updating badge \(newBadgeNumber)")
        try await UNUserNotificationCenter.current().setBadgeCount(newBadgeNumber)
#endif
    }

    @MainActor
    var badgeNumber: Int {
#if os(watchOS)
        return 0
#elseif os(macOS)
        return Int(NSApplication.shared.dockTile.badgeLabel ?? "") ?? 0
#else
        // Covers iOS, tvOS, and visionOS
        return UIApplication.shared.applicationIconBadgeNumber
#endif
    }
}
