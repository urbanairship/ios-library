/* Copyright Airship and Contributors */

import Foundation

struct InAppFormDisplayEvent: InAppEvent {
    let name: String = "in_app_form_display"
    let data: (Sendable&Encodable)?

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
