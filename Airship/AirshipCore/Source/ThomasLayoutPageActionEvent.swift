/* Copyright Airship and Contributors */

import Foundation

struct ThomasLayoutPageActionEvent: ThomasLayoutEvent {
    public let name = EventType.inAppPageAction
    public let data: (any Sendable & Encodable)?
    
    public init(data: ThomasReportingEvent.PageActionEvent) {
        self.data = data
    }
}
