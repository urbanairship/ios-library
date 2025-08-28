/* Copyright Airship and Contributors */



struct ThomasActionsPayload: ThomasSerializable, Hashable {
    static let keyActionOverride = "platform_action_overrides"

    private let original: AirshipJSON
    private let merged: AirshipJSON

    var value: AirshipJSON {
        return merged
    }

    init(value: AirshipJSON) {
        self.original = value
        self.merged = Self.overridingPlatformActions(value)
    }

    init(from decoder: any Decoder) throws {
        let json = try AirshipJSON.init(from: decoder)

        guard case .object = json else {
            throw AirshipErrors.error("Invalid actions payload.")
        }

        self.original = json
        self.merged = Self.overridingPlatformActions(json)
    }

    func encode(to encoder: any Encoder) throws {
        try self.original.encode(to: encoder)
    }

    static func overridingPlatformActions(_ input: AirshipJSON) -> AirshipJSON {
        guard
            case .object(var actions) = input,
            let override = actions.removeValue(forKey: Self.keyActionOverride),
            case .object(let platforms) = override,
            case .object(let overridenActions) = platforms["ios"]
        else {
            return input
        }

        actions.merge(overridenActions) { _, overriden in
            overriden
        }

        return .object(actions)
    }
}
