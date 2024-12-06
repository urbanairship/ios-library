/* Copyright Airship and Contributors */

import Foundation

enum ThomasStateAction: ThomasSerializable {
    case setState(SetState)
    case clearState
    case formValue(SetFormValue)

    private enum CodingKeys: String, CodingKey {
        case type
    }

    enum ActionType: String, ThomasSerializable {
        case setState = "set"
        case clearState = "clear"
        case formValue = "set_form_value"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ActionType.self, forKey: .type)

        self = switch type {
        case .setState: .setState(try SetState(from: decoder))
        case .clearState: .clearState
        case .formValue: .formValue(try SetFormValue(from: decoder))
        }
    }

    func encode(to encoder: any Encoder) throws {
        switch self {
        case .setState(let action): try action.encode(to: encoder)
        case .clearState:
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(ActionType.clearState, forKey: .type)
        case .formValue(let action): try action.encode(to: encoder)
        }
    }

    struct SetState: ThomasSerializable {
        let type: ActionType = .setState
        let key: String
        let value: AirshipJSON?

        enum CodingKeys: String, CodingKey {
            case key
            case value
            case type
        }
    }

    struct SetFormValue: ThomasSerializable {
        let type: ActionType = .formValue
        let key: String

        enum CodingKeys: String, CodingKey {
            case key
            case type
        }
    }
}
