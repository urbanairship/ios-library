/* Copyright Airship and Contributors */



#if canImport(AirshipCore)
import AirshipCore
#endif

struct InAppFormResultEvent: InAppEvent {
    let name = EventType.inAppFormResult
    let data: (any Sendable & Encodable)?

    init(data: ThomasReportingEvent.FormResultEvent) {
        self.data = data
    }
}
