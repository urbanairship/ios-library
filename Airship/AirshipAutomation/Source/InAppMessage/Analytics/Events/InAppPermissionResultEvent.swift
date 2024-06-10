/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

struct InAppPermissionResultEvent: InAppEvent {
    let name = EventType.inAppPermissionResult
    let data: (Sendable&Encodable)?

    init(
        permission: AirshipPermission,
        startingStatus: AirshipPermissionStatus,
        endingStatus: AirshipPermissionStatus
    ) {
        self.data = PermissionResultData(
            permission: permission.stringValue,
            startingStatus: startingStatus.stringValue,
            endingStatus: endingStatus.stringValue
        )
    }

    private struct PermissionResultData: Encodable, Sendable {
        var permission: String
        var startingStatus: String
        var endingStatus: String

        enum CodingKeys: String, CodingKey {
            case permission
            case startingStatus = "starting_permission_status"
            case endingStatus = "ending_permission_status"
        }
    }
}
