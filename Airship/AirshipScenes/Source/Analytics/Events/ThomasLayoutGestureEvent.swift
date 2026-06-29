/* Copyright Airship and Contributors */

@_spi(AirshipInternal) import AirshipSceneRenderer
import Foundation
import AirshipCore

struct ThomasLayoutGestureEvent: ThomasLayoutEvent {
    public let name: AirshipEventType = AirshipEventType.inAppGesture
    public let data: (any Sendable & Encodable)?

    public init(data: ThomasReportingEvent.GestureEvent) {
        self.data = data
    }
}

