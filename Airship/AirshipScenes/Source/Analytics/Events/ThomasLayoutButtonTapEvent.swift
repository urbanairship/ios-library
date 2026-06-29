/* Copyright Airship and Contributors */

@_spi(AirshipInternal) import AirshipSceneRenderer
import Foundation
import AirshipCore

struct ThomasLayoutButtonTapEvent: ThomasLayoutEvent {
    public let name: AirshipEventType = AirshipEventType.inAppButtonTap
    public let data: (any Sendable & Encodable)?

    public init(data: ThomasReportingEvent.ButtonTapEvent) {
        self.data = data
    }
}
