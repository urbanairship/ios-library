/* Copyright Airship and Contributors */



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
    static func resolveOptional(
        state: ThomasState,
        overrides: [ThomasPropertyOverride<T>]?,
        defaultValue: T? = nil
    ) -> T? {
        let override = overrides?.first { override in
            return override.whenStateMatches?.evaluate(
                json: state.state
            ) ?? true
        }

        guard let override else {
            return defaultValue
        }

        return override.value
    }

    @MainActor
    static func resolveRequired(state: ThomasState, overrides: [ThomasPropertyOverride<T>]?, defaultValue: T) -> T {
        return resolveOptional(state: state, overrides: overrides) ?? defaultValue
    }
}
