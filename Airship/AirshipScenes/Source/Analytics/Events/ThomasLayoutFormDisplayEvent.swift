/* Copyright Airship and Contributors */

@_spi(AirshipInternal) import AirshipSceneRenderer
import Foundation
import AirshipCore

struct ThomasLayoutFormDisplayEvent: ThomasLayoutEvent {
    public let name: AirshipEventType = AirshipEventType.inAppFormDisplay
    public let data: (any Sendable & Encodable)?

    public init(data: ThomasReportingEvent.FormDisplayEvent) {
        self.data = data
    }
}
