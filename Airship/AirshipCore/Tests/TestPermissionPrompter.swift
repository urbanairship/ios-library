/* Copyright Airship and Contributors */

import Foundation

@testable import AirshipCore

class TestPermissionPrompter: PermissionPrompter {

    var onPrompt:
        (
            (
                AirshipPermission, Bool, Bool,
                (AirshipPermissionStatus, AirshipPermissionStatus) -> Void
            ) ->
                Void
        )?

    init() {}

    func prompt(
        permission: AirshipPermission,
        enableAirshipUsage: Bool,
        fallbackSystemSettings: Bool,
        completionHandler: @escaping (AirshipPermissionStatus, AirshipPermissionStatus) ->
            Void
    ) {

        if let onPrompt = self.onPrompt {
            onPrompt(
                permission,
                enableAirshipUsage,
                fallbackSystemSettings,
                completionHandler
            )
        } else {
            completionHandler(.notDetermined, .notDetermined)
        }
    }
}
