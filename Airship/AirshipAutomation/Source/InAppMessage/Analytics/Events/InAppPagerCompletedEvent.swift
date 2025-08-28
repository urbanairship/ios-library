/* Copyright Airship and Contributors */




#if canImport(AirshipCore)
import AirshipCore
#endif

struct InAppPagerCompletedEvent: InAppEvent {
    let name = EventType.inAppPagerCompleted
    let data: (any Sendable & Encodable)?

    init(data: ThomasReportingEvent.PagerCompletedEvent) {
        self.data = data
    }
}
