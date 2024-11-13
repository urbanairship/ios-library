/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

struct InAppFormResultEvent: InAppEvent {
    let name = EventType.inAppFormResult
    let data: (any Sendable & Encodable)?

    init(forms: AirshipJSON) {
        self.data = FormResultData(forms: forms)
    }

    private struct FormResultData: Encodable, Sendable {
        var forms: AirshipJSON
    }
}
