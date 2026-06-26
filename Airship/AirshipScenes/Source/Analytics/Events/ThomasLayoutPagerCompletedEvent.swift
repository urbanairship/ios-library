/* Copyright Airship and Contributors */

import Foundation
import AirshipCore

struct ThomasLayoutPagerCompletedEvent: ThomasLayoutEvent {
    public let name: AirshipEventType = AirshipEventType.inAppPagerCompleted
    public let data: (any Sendable & Encodable)?

    public init(data: ThomasReportingEvent.PagerCompletedEvent) {
        self.data = data
    }
}
