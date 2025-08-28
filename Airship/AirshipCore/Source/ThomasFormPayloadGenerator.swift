/* Copyright Airship and Contributors */



@MainActor
struct ThomasFormPayloadGenerator {
    private static let typeKey = "type"
    private static let valueKey = "value"
    private static let childrenKey = "children"
    private static let scoreIDKey = "score_id"
    private static let responseTypeKey = "response_type"
    private static let statusKey = "status"
    private static let resultKey = "result"
    private static let dataKey = "data"

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

        return .object([identifier: makeValuePayload(formValue) ?? .object([:])])
    }

    private static func makeValuePayload(
        _ value: ThomasFormField.Value,
        status: ThomasFormField.Status? = nil
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
        case .text(let value):
            return AirshipJSON.makeObject { builder in
                builder.set(string: "text_input", key: Self.typeKey)
                builder.set(string: value, key: Self.valueKey)
                if let status {
                    builder.set(json: makeFieldStatusPayload(status), key: Self.statusKey)
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

        case .sms(let value):
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
                        builder.set(json: Self.makeValuePayload($0.value), key: $0.key)
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
                        builder.set(json: Self.makeValuePayload($0.value), key: $0.key)
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
