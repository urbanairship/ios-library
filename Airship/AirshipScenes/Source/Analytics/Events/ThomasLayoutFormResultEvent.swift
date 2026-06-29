/* Copyright Airship and Contributors */

@_spi(AirshipInternal) import AirshipSceneRenderer
import Foundation
import AirshipCore

struct ThomasLayoutFormResultEvent: ThomasLayoutEvent {
    public let name: AirshipEventType = AirshipEventType.inAppFormResult
    public let data: (any Sendable & Encodable)?

    public init(data: ThomasReportingEvent.FormResultEvent) {
        self.data = data
    }
}
