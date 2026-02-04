/* Copyright Airship and Contributors */

import Foundation

struct ThomasLayoutGestureEvent: ThomasLayoutEvent {
    public let name: EventType = EventType.inAppGesture
    public let data: (any Sendable & Encodable)?

    public init(data: ThomasReportingEvent.GestureEvent) {
        self.data = data
    }
}

