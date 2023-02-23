/* Copyright Airship and Contributors */

import Foundation

typealias PermissionResultReceiver = (
    AirshipPermission, AirshipPermissionStatus, AirshipPermissionStatus
) -> Void

protocol PermissionPrompter {

    func prompt(
        permission: AirshipPermission,
        enableAirshipUsage: Bool,
        fallbackSystemSettings: Bool,
        completionHandler: @escaping (AirshipPermissionStatus, AirshipPermissionStatus) ->
            Void
    )
}

struct AirshipPermissionPrompter: PermissionPrompter {

    private let permissionsManager: AirshipPermissionsManager
    private let notificationCenter: NotificationCenter

    init(
        permissionsManager: AirshipPermissionsManager,
        notificationCenter: NotificationCenter = NotificationCenter.default
    ) {
        self.permissionsManager = permissionsManager
        self.notificationCenter = notificationCenter
    }

    func prompt(
        permission: AirshipPermission,
        enableAirshipUsage: Bool,
        fallbackSystemSettings: Bool,
        completionHandler: @escaping (AirshipPermissionStatus, AirshipPermissionStatus) ->
            Void
    ) {

        self.permissionsManager.checkPermissionStatus(permission) {
            startResult in
            if fallbackSystemSettings && startResult == .denied {
                #if !os(watchOS)
                self.requestSystemSettingsChange(permission: permission) {
                    endResult in
                    completionHandler(startResult, endResult)
                }
                #endif
            } else {
                self.permissionsManager.requestPermission(
                    permission,
                    enableAirshipUsageOnGrant: enableAirshipUsage
                ) { endResult in
                    completionHandler(startResult, endResult)
                }
            }
        }
    }

    #if !os(watchOS)

    private func requestSystemSettingsChange(
        permission: AirshipPermission,
        completionHandler: @escaping (AirshipPermissionStatus) -> Void
    ) {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url, options: [:]) { _ in

                var observer: Any? = nil
                observer = self.notificationCenter.addObserver(
                    forName: AppStateTracker.didBecomeActiveNotification,
                    object: nil,
                    queue: .main
                ) { _ in

                    if let observer = observer {
                        self.notificationCenter.removeObserver(observer)
                    }

                    self.permissionsManager.checkPermissionStatus(
                        permission,
                        completionHandler: completionHandler
                    )
                }
            }
        } else {
            AirshipLogger.error("Unable to navigate to system settings.")
            self.permissionsManager.checkPermissionStatus(
                permission,
                completionHandler: completionHandler
            )
        }
    }

    #endif

}
