/* Copyright Airship and Contributors */

import Foundation

struct ThomasValidationInfo: ThomasSerializable {
    var isRequired: Bool?
    var onError: ErrorInfo?
    var onEdit: EditInfo?
    var onValid: ValidInfo?

    struct ErrorInfo: ThomasSerializable {
        var stateActions: [ThomasStateAction]?
        
        /// If defined, `stateActions` will be ignored.
        var outcomes: [ThomasOutcome]?

        enum CodingKeys: String, CodingKey {
            case stateActions = "state_actions"
            case outcomes
        }
    }

    struct EditInfo: ThomasSerializable {
        var stateActions: [ThomasStateAction]?
        /// If defined, `stateActions` will be ignored.
        var outcomes: [ThomasOutcome]?

        enum CodingKeys: String, CodingKey {
            case stateActions = "state_actions"
            case outcomes
        }
    }

    struct ValidInfo: ThomasSerializable {
        var stateActions: [ThomasStateAction]?
        /// If defined, `stateActions` will be ignored.
        var outcomes: [ThomasOutcome]?

        enum CodingKeys: String, CodingKey {
            case stateActions = "state_actions"
            case outcomes
        }
    }

    enum CodingKeys: String, CodingKey {
        case isRequired = "required"
        case onError = "on_error"
        case onEdit = "on_edit"
        case onValid = "on_valid"
    }
}
