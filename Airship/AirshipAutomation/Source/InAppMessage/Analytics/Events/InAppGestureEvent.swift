/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

struct InAppGestureEvent: InAppEvent {
    let name = EventType.inAppGesture
    let data: (any Sendable & Encodable)?

    init(data: ThomasReportingEvent.GestureEvent) {
        self.data = data
    }
}

