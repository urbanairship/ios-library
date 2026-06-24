/* Copyright Airship and Contributors */

import Foundation

enum ThomasButtonTapEffect: ThomasSerializable {
    case `default`
    case none

    private enum CodingKeys: String, CodingKey {
        case type
    }

    enum EffectType: String, Codable {
        case `default` = "default"
        case none = "none"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type: EffectType = try container.decode(EffectType.self, forKey: .type)
        self = switch(type) {
        case .default: .default
        case .none: .none
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch (self) {
        case .default: try container.encode(EffectType.default, forKey: .type)
        case .none: try container.encode(EffectType.none, forKey: .type)
        }
    }
}
