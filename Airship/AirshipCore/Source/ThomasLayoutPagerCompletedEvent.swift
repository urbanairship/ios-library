/* Copyright Airship and Contributors */

import Foundation

struct ThomasLayoutPagerCompletedEvent: ThomasLayoutEvent {
    public let name: EventType = EventType.inAppPagerCompleted
    public let data: (any Sendable & Encodable)?

    public init(data: ThomasReportingEvent.PagerCompletedEvent) {
        self.data = data
    }
}
