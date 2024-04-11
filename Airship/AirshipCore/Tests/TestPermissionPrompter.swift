/* Copyright Airship and Contributors */

import Foundation

@testable import AirshipCore

final class TestPermissionPrompter: PermissionPrompter, @unchecked Sendable {

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
