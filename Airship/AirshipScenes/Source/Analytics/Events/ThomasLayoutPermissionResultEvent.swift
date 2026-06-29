/* Copyright Airship and Contributors */

@_spi(AirshipInternal) import AirshipSceneRenderer
import Foundation
public import AirshipCore

/// - Note: For internal use only. :nodoc:
public struct ThomasLayoutPermissionResultEvent: ThomasLayoutEvent {
    public let name: AirshipEventType = AirshipEventType.inAppPermissionResult
    public let data: (any Sendable & Encodable)?

    public init(
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
