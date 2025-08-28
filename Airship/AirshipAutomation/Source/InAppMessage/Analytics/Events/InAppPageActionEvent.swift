/* Copyright Airship and Contributors */



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
