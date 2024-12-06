/* Copyright Airship and Contributors */

import Foundation


enum ThomasToggleStyleInfo: ThomasSerializable {
    case switchStyle(Switch)
    case checkboxStyle(Checkbox)

    private enum CodingKeys: String, CodingKey {
        case type = "type"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(StyleType.self, forKey: .type)

        self = switch type {
        case .switch: .switchStyle(try Switch(from: decoder))
        case .checkbox: .checkboxStyle(try Checkbox(from: decoder))
        }
    }

    func encode(to encoder: any Encoder) throws {
        switch self {
        case .switchStyle(let style): try style.encode(to: encoder)
        case .checkboxStyle(let style): try style.encode(to: encoder)
        }
    }

    enum StyleType: String, ThomasSerializable {
        case `switch`
        case checkbox
    }

    struct Switch: ThomasSerializable {
        let type: StyleType = .switch
        let colors: ToggleColors

        private enum CodingKeys: String, CodingKey {
            case colors = "toggle_colors"
            case type
        }

        struct ToggleColors: ThomasSerializable {
            var on: ThomasColor
            var off: ThomasColor
        }
    }

    struct Checkbox: ThomasSerializable {
        let type: StyleType = .checkbox
        let bindings: Bindings

        private enum CodingKeys: String, CodingKey {
            case bindings
            case type
        }

        struct Bindings: ThomasSerializable {
            let selected: Binding
            let unselected: Binding
        }

        struct Binding: ThomasSerializable {
            let shapes: [ThomasShapeInfo]?
            let icon: ThomasIconInfo?
        }
    }
}
