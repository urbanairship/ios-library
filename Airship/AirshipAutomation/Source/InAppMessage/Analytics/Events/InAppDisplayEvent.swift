/* Copyright Airship and Contributors */

import Foundation
#if canImport(AirshipCore)
import AirshipCore
#endif

struct InAppDisplayEvent: InAppEvent {
    let name = EventType.inAppDisplay
    let data: (Sendable&Encodable)? = nil
}
