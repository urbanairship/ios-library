/* Copyright Airship and Contributors */

import Foundation

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
