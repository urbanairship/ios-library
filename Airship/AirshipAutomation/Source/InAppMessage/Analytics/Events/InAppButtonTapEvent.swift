/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

struct InAppButtonTapEvent: InAppEvent {
    let name = EventType.inAppButtonTap
    let data: (any Sendable & Encodable)?

    init(data: ThomasReportingEvent.ButtonTapEvent) {
        self.data = data
    }
}
