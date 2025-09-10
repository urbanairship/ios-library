// Copyright Airship and Contributors

import Foundation
import UIKit

#if os(watchOS)
import WatchKit
#endif

protocol BadgerProtocol: AnyObject, Sendable {
    func setBadgeNumber(_ newBadgeNumber: Int) async throws
    @MainActor
    var badgeNumber: Int { get }
}


/// - Note: For internal use only. :nodoc:
final class Badger: Sendable, BadgerProtocol {
    func setBadgeNumber(_ newBadgeNumber: Int) async throws {
#if !os(watchOS)
        AirshipLogger.debug(
            "Updating badge \(newBadgeNumber)"
        )
        
        try await UNUserNotificationCenter.current().setBadgeCount(newBadgeNumber)
#endif
    }

    var badgeNumber: Int {
        get {
#if !os(watchOS)
            return UIApplication.shared.applicationIconBadgeNumber
#else
            return 0
#endif
        }
    }

    public static let shared: Badger = Badger()
}

