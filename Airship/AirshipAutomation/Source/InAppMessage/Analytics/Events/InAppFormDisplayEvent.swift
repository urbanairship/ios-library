/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

struct InAppFormDisplayEvent: InAppEvent {
    let name = EventType.inAppFormDisplay
    let data: (any Sendable & Encodable)?

    init(data: ThomasReportingEvent.FormDisplayEvent) {
        self.data = data
    }
}
