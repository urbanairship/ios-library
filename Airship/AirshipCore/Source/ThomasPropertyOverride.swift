/* Copyright Airship and Contributors */

import Foundation

struct ThomasPropertyOverride<T: Codable&Sendable&Equatable>: ThomasSerializable {
    let whenStateMatches: JSONPredicate?
    let value: T?

    enum CodingKeys: String, CodingKey {
        case whenStateMatches = "when_state_matches"
        case value
    }
}


extension ThomasPropertyOverride {

    @MainActor
    static func resolveOptional(state: ViewState, overrides: [ThomasPropertyOverride<T>]?, defaultValue: T? = nil) -> T? {
        let override = overrides?.first { override in
            override.whenStateMatches?.evaluate(state.state) ?? true
        }

        guard let override else {
            return defaultValue
        }

        return override.value
    }

    @MainActor
    static func resolveRequired(state: ViewState, overrides: [ThomasPropertyOverride<T>]?, defaultValue: T) -> T {
        let override = overrides?.first { override in
            override.whenStateMatches?.evaluate(state.state) ?? true
        }

        guard let override else {
            return defaultValue
        }

        return override.value ?? defaultValue
    }
}
