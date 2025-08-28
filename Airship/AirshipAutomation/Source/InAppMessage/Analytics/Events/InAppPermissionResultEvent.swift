/* Copyright Airship and Contributors */



#if canImport(AirshipCore)
import AirshipCore
#endif

struct InAppPermissionResultEvent: InAppEvent {
    let name = EventType.inAppPermissionResult
    let data: (any Sendable & Encodable)?

    init(
        permission: AirshipPermission,
        startingStatus: AirshipPermissionStatus,
        endingStatus: AirshipPermissionStatus
    ) {
        self.data = PermissionResultData(
            permission: permission,
            startingStatus: startingStatus,
            endingStatus: endingStatus
        )
    }

    private struct PermissionResultData: Encodable, Sendable {
        var permission: AirshipPermission
        var startingStatus: AirshipPermissionStatus
        var endingStatus: AirshipPermissionStatus

        enum CodingKeys: String, CodingKey {
            case permission
            case startingStatus = "starting_permission_status"
            case endingStatus = "ending_permission_status"
        }
    }
}
