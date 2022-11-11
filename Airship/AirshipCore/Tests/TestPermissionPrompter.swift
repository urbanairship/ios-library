/* Copyright Airship and Contributors */

import Foundation

@testable import AirshipCore

class TestPermissionPrompter: PermissionPrompter {

    var onPrompt:
        (
            (
                Permission, Bool, Bool,
                (PermissionStatus, PermissionStatus) -> Void
            ) ->
                Void
        )?

    init() {}

    func prompt(
        permission: Permission,
        enableAirshipUsage: Bool,
        fallbackSystemSettings: Bool,
        completionHandler: @escaping (PermissionStatus, PermissionStatus) ->
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
