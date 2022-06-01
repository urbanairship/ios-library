// Copyright Airship and Contributors

import Foundation
import UserNotifications

class NotificationPermissionDelegate: PermissionDelegate {

    struct Config {
        let options: UANotificationOptions
        let skipIfEphemeral: Bool
    }

    let registrar: NotificationRegistrar
    let config: () -> Config

    init(registrar: NotificationRegistrar, config: @escaping () -> Config) {
        self.registrar = registrar
        self.config = config
    }

    func checkPermissionStatus(completionHandler: @escaping (PermissionStatus) -> Void) {
        registrar.checkStatus { status, _ in
            completionHandler(status.permissionStatus)
        }
    }

    func requestPermission(completionHandler: @escaping (PermissionStatus) -> Void) {
        let config = self.config()
        self.registrar.updateRegistration(options: config.options,
                                          skipIfEphemeral: config.skipIfEphemeral) {
            self.checkPermissionStatus(completionHandler: completionHandler)
        }
    }
}

extension UAAuthorizationStatus {
    var permissionStatus: PermissionStatus {
        switch(self) {
        case .authorized: return .granted
        case .provisional: return .granted
        case .ephemeral: return .granted
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        @unknown default: return .notDetermined
        }

    }
}


