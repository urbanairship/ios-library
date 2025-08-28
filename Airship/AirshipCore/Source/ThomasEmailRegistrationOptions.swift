/* Copyright Airship and Contributors */



enum ThomasEmailRegistrationOption: ThomasSerializable, Hashable {
    case doubleOptIn(DoubleOptIn)
    case commercial(Commercial)
    case transactional(Transactional)

    struct DoubleOptIn: ThomasSerializable, Hashable {
        let type: EmailRegistrationType = .doubleOptIn
        var properties: AirshipJSON?

        enum CodingKeys: String, CodingKey {
            case type
            case properties
        }
    }

    struct Commercial: ThomasSerializable, Hashable {
        let type: EmailRegistrationType = .commercial
        var optedIn: Bool
        var properties: AirshipJSON?

        enum CodingKeys: String, CodingKey {
            case type
            case properties
            case optedIn = "commercial_opted_in"
        }
    }

    struct Transactional: ThomasSerializable, Hashable {
        let type: EmailRegistrationType = .transactional
        var properties: AirshipJSON?

        enum CodingKeys: String, CodingKey {
            case type
            case properties
        }
    }

    enum EmailRegistrationType: String, Codable {
        case doubleOptIn = "double_opt_in"
        case commercial = "commercial"
        case transactional = "transactional"
    }

    private enum CodingKeys: String, CodingKey {
        case type
    }

    func encode(to encoder: any Encoder) throws {
        switch self {
        case .doubleOptIn(let properties):
            try properties.encode(to: encoder)
        case .commercial(let properties):
            try properties.encode(to: encoder)
        case .transactional(let properties):
            try properties.encode(to: encoder)
        }
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(EmailRegistrationType.self, forKey: .type)
        switch type {
        case .doubleOptIn:
            self = .doubleOptIn(
                try DoubleOptIn(from: decoder)
            )
        case .commercial:
            self = .commercial(
                try Commercial(from: decoder)
            )
        case .transactional:
            self = .transactional(
                try Transactional(from: decoder)
            )
        }
    }
}

extension ThomasEmailRegistrationOption {
    func makeContactOptions(date: Date = Date.now) -> EmailRegistrationOptions {
        switch (self) {
        case .commercial(let properties):
            return .commercialOptions(
                transactionalOptedIn: nil,
                commercialOptedIn: properties.optedIn ? date : nil,
                properties: properties.properties?.unWrap() as? [String: Any]
            )
        case .doubleOptIn(let properties):
            return .options(
                properties: properties.properties?.unWrap() as? [String: Any],
                doubleOptIn: true
            )
        case .transactional(let properties):
            return .options(
                transactionalOptedIn: nil,
                properties: properties.properties?.unWrap() as? [String: Any],
                doubleOptIn: false
            )
        }
    }
}
