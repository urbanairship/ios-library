/* Copyright Airship and Contributors */



@testable import AirshipCore

final class TestPermissionPrompter: PermissionPrompter, @unchecked Sendable {

    var onPrompt:
        (
            (
                AirshipPermission, Bool, Bool
            ) ->
            AirshipPermissionResult
        )?

    init() {}

    func prompt(
        permission: AirshipPermission,
        enableAirshipUsage: Bool,
        fallbackSystemSettings: Bool) async ->  AirshipPermissionResult  {

        if let onPrompt = self.onPrompt {
            return onPrompt(
                permission,
                enableAirshipUsage,
                fallbackSystemSettings
            )
        } else {
            return AirshipPermissionResult.notDetermined
        }
    }
}
