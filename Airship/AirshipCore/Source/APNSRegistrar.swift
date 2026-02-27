// Copyright Airship and Contributors

import Foundation

@MainActor
protocol APNSRegistrar: Sendable {
    var isRegisteredForRemoteNotifications: Bool { get }
    func registerForRemoteNotifications()
    var isRemoteNotificationBackgroundModeEnabled: Bool { get }
    var isBackgroundRefreshStatusAvailable: Bool { get }
}

#if os(watchOS)
import WatchKit

final class DefaultAPNSRegistrar: APNSRegistrar {
    var isRegisteredForRemoteNotifications: Bool {
        WKExtension.shared().isRegisteredForRemoteNotifications
    }

    func registerForRemoteNotifications() {
        WKExtension.shared().registerForRemoteNotifications()
    }

    var isRemoteNotificationBackgroundModeEnabled: Bool {
        return true
    }

    var isBackgroundRefreshStatusAvailable: Bool {
        return true
    }
}


#elseif os(macOS)
import AppKit

final class DefaultAPNSRegistrar: APNSRegistrar {
    var isRegisteredForRemoteNotifications: Bool {
        return NSApplication.shared.isRegisteredForRemoteNotifications
    }

    func registerForRemoteNotifications() {
        NSApplication.shared.registerForRemoteNotifications()
    }

    var isRemoteNotificationBackgroundModeEnabled: Bool {
        return true
    }

    var isBackgroundRefreshStatusAvailable: Bool {
        return true
    }
}

#elseif canImport(UIKit)
import UIKit

final class DefaultAPNSRegistrar: APNSRegistrar {
    var isRegisteredForRemoteNotifications: Bool {
        return UIApplication.shared.isRegisteredForRemoteNotifications
    }

    func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }

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
        return Self._isRemoteNotificationBackgroundModeEnabled
    }

    var isBackgroundRefreshStatusAvailable: Bool {
#if os(tvOS)
        return true
#else
        // This covers iOS and iPadOS
        return UIApplication.shared.backgroundRefreshStatus == .available
#endif
    }
}

#endif
