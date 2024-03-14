// Copyright Airship and Contributors

import Foundation
import UserNotifications

final class NotificationPermissionDelegate: AirshipPermissionDelegate {

    struct Config: Sendable {
        let options: UANotificationOptions
        let skipIfEphemeral: Bool
    }

    let registrar: NotificationRegistrar
    let config: @Sendable () -> Config

    init(registrar: NotificationRegistrar, config: @Sendable @escaping () -> Config) {
        self.registrar = registrar
        self.config = config
    }

    func checkPermissionStatus() async -> AirshipPermissionStatus {
        return await registrar.checkStatus().0.permissionStatus
    }

    func requestPermission() async -> AirshipPermissionStatus {
        let config = self.config()
        await self.registrar.updateRegistration(
            options: config.options,
            skipIfEphemeral: config.skipIfEphemeral
        )
        return await self.checkPermissionStatus()
    }
}

extension UAAuthorizationStatus {
    var permissionStatus: AirshipPermissionStatus {
        switch self {
        case .authorized: return .granted
        case .provisional: return .granted
        case .ephemeral: return .granted
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        @unknown default: return .notDetermined
        }

    }
}
