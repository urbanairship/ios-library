/* Copyright Airship and Contributors */


#if canImport(AirshipCore)
import AirshipCore
#endif

struct InAppDisplayEvent: InAppEvent {
    let name = EventType.inAppDisplay
    let data: (any Sendable & Encodable)? = nil
}
