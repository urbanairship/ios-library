// Copyright Airship and Contributors


import UIKit

#if os(watchOS)
import WatchKit
#endif

@MainActor
protocol APNSRegistrar: Sendable {
    var isRegisteredForRemoteNotifications: Bool { get }
    func registerForRemoteNotifications()
    var isRemoteNotificationBackgroundModeEnabled: Bool { get }
    #if !os(watchOS)
    var isBackgroundRefreshStatusAvailable: Bool { get }
    #endif
}

#if !os(watchOS)

final class UIApplicationAPNSRegistrar: APNSRegistrar {
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
        return UIApplication.shared.backgroundRefreshStatus == .available
    }
}
#else


final class WKExtensionAPNSRegistrar: APNSRegistrar {
    var isRegisteredForRemoteNotifications: Bool {
        WKExtension.shared().isRegisteredForRemoteNotifications
    }

    func registerForRemoteNotifications() {
        WKExtension.shared().registerForRemoteNotifications()
    }
    
    var isRemoteNotificationBackgroundModeEnabled: Bool {
        return true
    }
}

#endif
