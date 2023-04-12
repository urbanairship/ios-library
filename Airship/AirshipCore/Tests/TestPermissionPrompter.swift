/* Copyright Airship and Contributors */

import Foundation

@testable import AirshipCore

class TestPermissionPrompter: PermissionPrompter {

    var onPrompt:
        (
            (
                AirshipPermission, Bool, Bool
            ) ->
            (AirshipPermissionStatus, AirshipPermissionStatus)
        )?

    init() {}

    func prompt(
        permission: AirshipPermission,
        enableAirshipUsage: Bool,
        fallbackSystemSettings: Bool) async ->  (AirshipPermissionStatus, AirshipPermissionStatus) {

        if let onPrompt = self.onPrompt {
            return onPrompt(
                permission,
                enableAirshipUsage,
                fallbackSystemSettings
            )
        } else {
            return(.notDetermined, .notDetermined)
        }
    }
}
