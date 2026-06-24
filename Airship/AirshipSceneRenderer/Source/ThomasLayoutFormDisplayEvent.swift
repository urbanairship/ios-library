/* Copyright Airship and Contributors */

import Foundation
import AirshipCore

struct ThomasLayoutFormDisplayEvent: ThomasLayoutEvent {
    public let name: EventType = EventType.inAppFormDisplay
    public let data: (any Sendable & Encodable)?

    public init(data: ThomasReportingEvent.FormDisplayEvent) {
        self.data = data
    }
}
