/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

struct InAppFormDisplayEvent: InAppEvent {
    let name = EventType.inAppFormDisplay
    let data: (Sendable&Encodable)?

    init(formInfo: ThomasFormInfo) {
        self.init(
            identifier: formInfo.identifier,
            formType: formInfo.formType,
            responseType: formInfo.formResponseType
        )
    }

    init(identifier: String, formType: String, responseType: String?) {
        self.data = FormDisplayData(
            identifier: identifier,
            formType: formType,
            responseType: responseType
        )
    }

    private struct FormDisplayData: Encodable, Sendable {
        var identifier: String
        var formType: String
        var responseType: String?

        enum CodingKeys: String, CodingKey {
            case identifier = "form_identifier"
            case formType = "form_type"
            case responseType = "form_response_type"
        }
    }
}
