/* Copyright Airship and Contributors */

import Foundation
import AirshipCore

struct ThomasLayoutPageViewEvent: ThomasLayoutEvent {
    public let name: AirshipEventType = AirshipEventType.inAppPageView
    public let data: (any Sendable & Encodable)?

    public init(data: ThomasReportingEvent.PageViewEvent) {
        self.data = data
    }
}

