/* Copyright Airship and Contributors */

import Foundation

struct ThomasLayoutFormResultEvent: ThomasLayoutEvent {
    public let name: EventType = EventType.inAppFormResult
    public let data: (any Sendable & Encodable)?

    public init(data: ThomasReportingEvent.FormResultEvent) {
        self.data = data
    }
}
