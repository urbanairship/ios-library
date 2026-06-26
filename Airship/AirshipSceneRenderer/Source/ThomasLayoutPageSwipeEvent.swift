/* Copyright Airship and Contributors */

import Foundation
import AirshipCore

struct ThomasLayoutPageSwipeEvent: ThomasLayoutEvent {
    public let name: AirshipEventType = AirshipEventType.inAppPageSwipe
    public let data: (any Sendable & Encodable)?

    public init(data: ThomasReportingEvent.PageSwipeEvent) {
        self.data = data
    }
}
