/* Copyright Airship and Contributors */

import Foundation
import AirshipCore

struct ThomasLayoutPagerSummaryEvent: ThomasLayoutEvent {
    public let name: EventType = EventType.inAppPagerSummary
    public let data: (any Sendable & Encodable)?

    public init(data: ThomasReportingEvent.PagerSummaryEvent) {
        self.data = data
    }
}
