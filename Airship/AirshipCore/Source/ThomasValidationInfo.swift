/* Copyright Airship and Contributors */



struct ThomasValidationInfo: ThomasSerializable {
    var isRequired: Bool?
    var onError: ErrorInfo?
    var onEdit: EditInfo?
    var onValid: ValidInfo?

    struct ErrorInfo: ThomasSerializable {
        var stateActions: [ThomasStateAction]?

        enum CodingKeys: String, CodingKey {
            case stateActions = "state_actions"
        }
    }

    struct EditInfo: ThomasSerializable {
        var stateActions: [ThomasStateAction]?

        enum CodingKeys: String, CodingKey {
            case stateActions = "state_actions"
        }
    }

    struct ValidInfo: ThomasSerializable {
        var stateActions: [ThomasStateAction]?

        enum CodingKeys: String, CodingKey {
            case stateActions = "state_actions"
        }
    }

    enum CodingKeys: String, CodingKey {
        case isRequired = "required"
        case onError = "on_error"
        case onEdit = "on_edit"
        case onValid = "on_valid"
    }
}
