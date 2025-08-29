/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

struct InAppPageActionEvent: InAppEvent {
    let name = EventType.inAppPageAction
    let data: (any Sendable & Encodable)?
    
    
    init(data: ThomasReportingEvent.PageActionEvent) {
        self.data = data
    }
}
