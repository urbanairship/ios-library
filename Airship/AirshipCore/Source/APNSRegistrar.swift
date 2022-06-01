// Copyright Airship and Contributors

import Foundation
import UIKit

protocol APNSRegistrar {
    var isRegisteredForRemoteNotifications: Bool { get }
    func registerForRemoteNotifications() -> Void
    var isBackgroundRefreshStatusAvailable: Bool { get }
    var isRemoteNotificationBackgroundModeEnabled: Bool { get }
}

extension UIApplication: APNSRegistrar {
    static var _isRemoteNotificationBackgroundModeEnabled: Bool {
        let backgroundModes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [Any]
        return backgroundModes?.contains(where: { ($0 as? String) == "remote-notification" }) == true
    }

    var isRemoteNotificationBackgroundModeEnabled: Bool {
        return UIApplication._isRemoteNotificationBackgroundModeEnabled
    }

    var isBackgroundRefreshStatusAvailable: Bool {
        return self.backgroundRefreshStatus == .available
    }
}
