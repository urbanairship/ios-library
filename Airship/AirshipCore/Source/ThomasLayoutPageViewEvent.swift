/* Copyright Airship and Contributors */

import Foundation

struct ThomasLayoutPageViewEvent: ThomasLayoutEvent {
    public let name = EventType.inAppPageView
    public let data: (any Sendable & Encodable)?

    public init(data: ThomasReportingEvent.PageViewEvent) {
        self.data = data
    }
}

