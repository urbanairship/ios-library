/* Copyright Airship and Contributors */



#if canImport(AirshipCore)
import AirshipCore
#endif

struct InAppPageViewEvent: InAppEvent {
    let name = EventType.inAppPageView
    let data: (any Sendable & Encodable)?

    init(data: ThomasReportingEvent.PageViewEvent) {
        self.data = data
    }
}

