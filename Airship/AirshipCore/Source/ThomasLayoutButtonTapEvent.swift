/* Copyright Airship and Contributors */

import Foundation

struct ThomasLayoutButtonTapEvent: ThomasLayoutEvent {
    public let name = EventType.inAppButtonTap
    public let data: (any Sendable & Encodable)?

    public init(data: ThomasReportingEvent.ButtonTapEvent) {
        self.data = data
    }
}
