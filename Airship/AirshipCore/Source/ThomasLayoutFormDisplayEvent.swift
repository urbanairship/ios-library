/* Copyright Airship and Contributors */

import Foundation

struct ThomasLayoutFormDisplayEvent: ThomasLayoutEvent {
    public let name = EventType.inAppFormDisplay
    public let data: (any Sendable & Encodable)?

    public init(data: ThomasReportingEvent.FormDisplayEvent) {
        self.data = data
    }
}
