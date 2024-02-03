/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

struct InAppPageActionEvent: InAppEvent {
    let name: String = "in_app_page_action"
    let data: (Sendable&Encodable)?


    init(identifier: String, reportingMetadata: AirshipJSON?) {
        self.data = PageActionData(
            identifier: identifier,
            reportingMetadata: reportingMetadata
        )
    }

    private struct PageActionData: Encodable, Sendable {
        var identifier: String
        var reportingMetadata: AirshipJSON?

        enum CodingKeys: String, CodingKey {
            case identifier = "action_identifier"
            case reportingMetadata = "reporting_metadata"
        }
    }
}
