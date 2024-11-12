/* Copyright Airship and Contributors */

import Foundation

struct ThomasValidationInfo: ThomasSerializable {
    var isRequired: Bool?
    var onError: ErrorInfo?
    var onErrorCleared: ClearedInfo?

    struct ErrorInfo: ThomasSerializable {
        var stateActions: [ThomasStateAction]?

        enum CodingKeys: String, CodingKey {
            case stateActions = "state_actions"
        }
    }

    struct ClearedInfo: ThomasSerializable {
        var stateActions: [ThomasStateAction]?

        enum CodingKeys: String, CodingKey {
            case stateActions = "state_actions"
        }
    }

    enum CodingKeys: String, CodingKey {
        case isRequired = "required"
        case onError = "on_error"
        case onErrorCleared = "on_error_cleared"
    }
}
