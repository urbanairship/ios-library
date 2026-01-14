/* Copyright Airship and Contributors */

import Foundation

struct ThomasLayoutPagerSummaryEvent: ThomasLayoutEvent {
    public let name = EventType.inAppPagerSummary
    public let data: (any Sendable & Encodable)?

    public init(data: ThomasReportingEvent.PagerSummaryEvent) {
        self.data = data
    }
}
