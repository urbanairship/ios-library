/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

struct InAppPagerSummaryEvent: InAppEvent {
    let name = EventType.inAppPagerSummary
    let data: (any Sendable & Encodable)?

    init(data: ThomasReportingEvent.PagerSummaryEvent) {
        self.data = data
    }
}
