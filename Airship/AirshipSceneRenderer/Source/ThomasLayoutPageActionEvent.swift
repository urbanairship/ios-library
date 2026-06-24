/* Copyright Airship and Contributors */

import Foundation
import AirshipCore

struct ThomasLayoutPageActionEvent: ThomasLayoutEvent {
    public let name: EventType = EventType.inAppPageAction
    public let data: (any Sendable & Encodable)?
    
    public init(data: ThomasReportingEvent.PageActionEvent) {
        self.data = data
    }
}
