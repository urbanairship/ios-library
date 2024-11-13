/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

struct InAppGestureEvent: InAppEvent {
    let name = EventType.inAppGesture
    let data: (any Sendable & Encodable)?


    init(identifier: String, reportingMetadata: AirshipJSON?) {
        self.data = GestureData(
            identifier: identifier,
            reportingMetadata: reportingMetadata
        )
    }

    private struct GestureData: Encodable, Sendable {
        var identifier: String
        var reportingMetadata: AirshipJSON?

        enum CodingKeys: String, CodingKey {
            case identifier = "gesture_identifier"
            case reportingMetadata = "reporting_metadata"
        }
    }
}

