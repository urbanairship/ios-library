// Copyright Airship and Contributors

import Foundation
import UIKit

#if os(watchOS)
import WatchKit
#endif

protocol APNSRegistrar: Sendable {
    @MainActor
    var isRegisteredForRemoteNotifications: Bool { get }
    @MainActor
    func registerForRemoteNotifications()
    @MainActor
    var isRemoteNotificationBackgroundModeEnabled: Bool { get }
    #if !os(watchOS)
    @MainActor
    var isBackgroundRefreshStatusAvailable: Bool { get }
    #endif
}

#if !os(watchOS)

extension UIApplication: @retroactive Sendable {}
extension UIApplication: APNSRegistrar {
    static var _isRemoteNotificationBackgroundModeEnabled: Bool {
        let backgroundModes =
            Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes")
            as? [Any]
        return backgroundModes?
            .contains(where: {
                ($0 as? String) == "remote-notification"
            }) == true
    }

    var isRemoteNotificationBackgroundModeEnabled: Bool {
        return UIApplication._isRemoteNotificationBackgroundModeEnabled
    }

    var isBackgroundRefreshStatusAvailable: Bool {
        return self.backgroundRefreshStatus == .available
    }
}

#else

extension WKExtension: APNSRegistrar {
    var isRemoteNotificationBackgroundModeEnabled: Bool {
        return true

    }
}

#endif
