/* Copyright Airship and Contributors */

import Foundation

struct ThomasLayoutPageSwipeEvent: ThomasLayoutEvent {
    public let name: EventType = EventType.inAppPageSwipe
    public let data: (any Sendable & Encodable)?

    public init(data: ThomasReportingEvent.PageSwipeEvent) {
        self.data = data
    }
}
