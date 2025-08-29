/* Copyright Airship and Contributors */

import Foundation
import Combine

typealias PermissionResultReceiver = @Sendable (
    AirshipPermission, AirshipPermissionStatus, AirshipPermissionStatus
) async -> Void

protocol PermissionPrompter: Sendable {

    func prompt(
        permission: AirshipPermission,
        enableAirshipUsage: Bool,
        fallbackSystemSettings: Bool
    ) async ->  AirshipPermissionResult
}

struct AirshipPermissionPrompter: PermissionPrompter {

    private let permissionsManager: AirshipPermissionsManager

    init(
        permissionsManager: AirshipPermissionsManager
    ) {
        self.permissionsManager = permissionsManager
    }

    @MainActor
    func prompt(
        permission: AirshipPermission,
        enableAirshipUsage: Bool,
        fallbackSystemSettings: Bool
    ) async -> AirshipPermissionResult {
        return await self.permissionsManager.requestPermission(
            permission,
            enableAirshipUsageOnGrant: enableAirshipUsage,
            fallback: fallbackSystemSettings ? .systemSettings : .none
        )
    }
}
