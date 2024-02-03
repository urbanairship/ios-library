/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

struct InAppButtonTapEvent: InAppEvent {
    let name: String = "in_app_button_tap"
    let data: (Sendable&Encodable)?

    init(identifier: String, reportingMetadata: AirshipJSON?) {
        self.data = ButtonTapData(
            identifier: identifier,
            reportingMetadata: reportingMetadata
        )
    }

    private struct ButtonTapData: Encodable, Sendable {
        var identifier: String
        var reportingMetadata: AirshipJSON?


        enum CodingKeys: String, CodingKey {
            case identifier = "button_identifier"
            case reportingMetadata = "reporting_metadata"
        }
    }
}
