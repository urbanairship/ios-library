/* Copyright Airship and Contributors */

import Foundation
@_spi(AirshipInternal) import AirshipBasement

@MainActor
struct ThomasFormPayloadGenerator {
    private static let typeKey: String = "type"
    private static let valueKey: String = "value"
    private static let childrenKey: String = "children"
    private static let scoreIDKey: String = "score_id"
    private static let responseTypeKey: String = "response_type"
    private static let statusKey: String = "status"
    private static let resultKey: String = "result"
    private static let dataKey: String = "data"
    private static let aiKey: String = "ai"
    private static let aiInferenceKey: String = "ai_inference"

    /**
     * This is using an opaque AirshipJSON instead of structured types so we could expose the value to
     * the automation framework when it was written in obj-c. Eventually we should use structured types
     * that are encodable so we can have better type safety.
     */

    static func makeFormStatePayload(
        status: ThomasFormState.Status,
        fields: [ThomasFormField],
        formType: ThomasFormState.FormType
    ) -> AirshipJSON {

        let data = AirshipJSON.makeObject { builder in
            let childData = AirshipJSON.makeObject { builder in
                fields.forEach {
                    builder.set(
                        json: makeValuePayload($0.input, status: $0.status),
                        key: $0.identifier
                    )
                }
            }
            builder.set(json: childData, key: Self.childrenKey)
            switch(formType) {
            case .nps(let scoreID):
                builder.set(string: "nps", key: Self.typeKey)
                builder.set(string: scoreID, key: Self.scoreIDKey)
            case .form:
                builder.set(string: "form", key: Self.typeKey)
            }

        }

        return .object(
            [
                Self.dataKey: data,
                Self.statusKey: makeFormStatusPayload(status)
            ]
        )
    }

    static func makeFormEventPayload(
        identifier: String,
        formValue: ThomasFormField.Value
    ) throws -> AirshipJSON {
        let isForm = switch(formValue) {
        case .form, .npsForm: true
        default: false
        }

        guard isForm else {
            throw AirshipErrors.error("Form value should be form or npsForm")
        }

        // The event payload is the one place AI inference results are reported.
        return .object([identifier: makeValuePayload(formValue, includeAIInference: true) ?? .object([:])])
    }

    /// - Parameter includeAIInference: emit the `ai_inference` payload carried on a text
    ///   value. Only the form event payload sets this — the state projection omits it.
    private static func makeValuePayload(
        _ value: ThomasFormField.Value,
        status: ThomasFormField.Status? = nil,
        includeAIInference: Bool = false
    ) -> AirshipJSON? {
        switch value {
        case .toggle(let value):
            return AirshipJSON.makeObject { builder in
                builder.set(string: "toggle", key: Self.typeKey)
                builder.set(bool: value, key: Self.valueKey)
                if let status {
                    builder.set(json: makeFieldStatusPayload(status), key: Self.statusKey)
                }
            }
        case .radio(let value):
            return AirshipJSON.makeObject { builder in
                builder.set(string: "single_choice", key: Self.typeKey)
                builder.set(json: value, key: Self.valueKey)
                if let status {
                    builder.set(json: makeFieldStatusPayload(status), key: Self.statusKey)
                }
            }
        case .multipleCheckbox(let value):
            return AirshipJSON.makeObject { builder in
                builder.set(string: "multiple_choice", key: Self.typeKey)
                builder.set(array: Array(value), key: Self.valueKey)
                if let status {
                    builder.set(json: makeFieldStatusPayload(status), key: Self.statusKey)
                }
            }
        case .text(let value, let aiInference, let isRedacted):
            return AirshipJSON.makeObject { builder in
                builder.set(string: "text_input", key: Self.typeKey)
                if isRedacted == true {
                    builder.set(string: "REDACTED", key: Self.valueKey)
                    builder.set(bool: true, key: "is_redacted")
                } else {
                    builder.set(string: value, key: Self.valueKey)
                }
                if let status {
                    builder.set(json: makeFieldStatusPayload(status), key: Self.statusKey)
                }
                if includeAIInference, let aiInference {
                    builder.set(json: try? AirshipJSON.wrap(aiInference), key: Self.aiInferenceKey)
                }
            }
        case .email(let value):
            return AirshipJSON.makeObject { builder in
                builder.set(string: "email_input", key: Self.typeKey)
                builder.set(string: value, key: Self.valueKey)
                if let status {
                    builder.set(json: makeFieldStatusPayload(status), key: Self.statusKey)
                }
            }

        case .sms(let value, _):
            return AirshipJSON.makeObject { builder in
                builder.set(string: "sms_input", key: Self.typeKey)
                builder.set(string: value, key: Self.valueKey)
                if let status {
                    builder.set(json: makeFieldStatusPayload(status), key: Self.statusKey)
                }
            }
        case .score(let value):

            return AirshipJSON.makeObject { builder in
                builder.set(string: "score", key: Self.typeKey)
                builder.set(json: value, key: Self.valueKey)
                if let status {
                    builder.set(json: makeFieldStatusPayload(status), key: Self.statusKey)
                }
            }
        case .form(let responseType, let children):
            return AirshipJSON.makeObject { builder in
                builder.set(string: "form", key: Self.typeKey)
                builder.set(string: responseType, key: Self.responseTypeKey)

                if let status {
                    builder.set(json: makeFieldStatusPayload(status), key: Self.statusKey)
                }

                let children = AirshipJSON.makeObject { builder in
                    children.forEach {
                        builder.set(
                            json: Self.makeValuePayload($0.value, includeAIInference: includeAIInference),
                            key: $0.key
                        )
                    }
                }

                builder.set(json: children, key: Self.childrenKey)

            }
        case .npsForm(let responseType, let scoreID, let children):
            return AirshipJSON.makeObject { builder in
                builder.set(string: "nps", key: Self.typeKey)
                builder.set(string: responseType, key: Self.responseTypeKey)
                builder.set(string: scoreID, key: Self.scoreIDKey)

                if let status {
                    builder.set(json: makeFieldStatusPayload(status), key: Self.statusKey)
                }

                let children = AirshipJSON.makeObject { builder in
                    children.forEach {
                        builder.set(
                            json: Self.makeValuePayload($0.value, includeAIInference: includeAIInference),
                            key: $0.key
                        )
                    }
                }

                builder.set(json: children, key: Self.childrenKey)
            }
        }
    }

    private static func makeFieldStatusPayload(_ status: ThomasFormField.Status) -> AirshipJSON {
        AirshipJSON.makeObject { builder in
            switch(status) {
            case .valid(let result):
                builder.set(string: "valid", key: Self.typeKey)
                builder.set(json: makeValuePayload(result.value), key: Self.resultKey)
                builder.set(json: result.aiInference, key: Self.aiKey)
            case .invalid:
                builder.set(string: "invalid", key: Self.typeKey)
            case .pending:
                builder.set(string: "pending", key: Self.typeKey)
            case .error:
                builder.set(string: "error", key: Self.typeKey)
            }
        }
    }

    private static func makeFormStatusPayload(_ status: ThomasFormState.Status) -> AirshipJSON {
        AirshipJSON.makeObject { builder in
            builder.set(string: status.rawValue, key: Self.typeKey)
        }
    }
}
