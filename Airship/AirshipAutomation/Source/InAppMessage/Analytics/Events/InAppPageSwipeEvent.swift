/* Copyright Airship and Contributors */




#if canImport(AirshipCore)
import AirshipCore
#endif


struct InAppPageSwipeEvent: InAppEvent {
    let name = EventType.inAppPageSwipe
    let data: (any Sendable & Encodable)?

    init(data: ThomasReportingEvent.PageSwipeEvent) {
        self.data = data
    }
}
