/* Copyright Airship and Contributors */

@_spi(AirshipInternal) import AirshipSceneRenderer
import Foundation
import AirshipCore

struct ThomasLayoutPageSwipeEvent: ThomasLayoutEvent {
    public let name: AirshipEventType = AirshipEventType.inAppPageSwipe
    public let data: (any Sendable & Encodable)?

    public init(data: ThomasReportingEvent.PageSwipeEvent) {
        self.data = data
    }
}
