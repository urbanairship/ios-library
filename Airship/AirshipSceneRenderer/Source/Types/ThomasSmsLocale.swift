/* Copyright Airship and Contributors */

import Foundation

/// Locale configuration for a phone number
@_spi(AirshipInternal)
public struct ThomasSMSLocale: ThomasSerializable {
    /// Country locale code (two letters)
    public let countryCode: String

    /// Country phone code
    public let prefix: String

    /// Registration info
    public let registration: ThomasSMSRegistrationOption?

    // Validation hints
    let validationHints: ValidationHints?

    init(
        countryCode: String,
        prefix: String,
        registration: ThomasSMSRegistrationOption? = nil,
        validationHints: ValidationHints? = nil
    ) {
        self.countryCode = countryCode
        self.prefix = prefix
        self.registration = registration
        self.validationHints = validationHints
    }
    
    struct ValidationHints: ThomasSerializable {
        var minDigits: Int?
        var maxDigits: Int?

        enum CodingKeys: String, CodingKey {
            case minDigits = "min_digits"
            case maxDigits = "max_digits"
        }
    }

    enum CodingKeys: String, CodingKey {
        case countryCode = "country_code"
        case prefix
        case registration
        case validationHints = "validation_hints"
    }
}

@_spi(AirshipInternal)
@frozen
public enum ThomasSMSRegistrationOption: ThomasSerializable, Hashable {
    case optIn(OptIn)

    public struct OptIn: ThomasSerializable, Hashable {

        public let type: RegistrationType = .optIn
        public var senderID: String

        enum CodingKeys: String, CodingKey {
            case type
            case senderID = "sender_id"
        }
    }

    public enum RegistrationType: String, Codable, Sendable {
        case optIn = "opt_in"
    }

    private enum CodingKeys: String, CodingKey {
        case type
    }

    public func encode(to encoder: any Encoder) throws {
        switch self {
        case .optIn(let properties):
            try properties.encode(to: encoder)
        }
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(RegistrationType.self, forKey: .type)
        switch type {
        case .optIn:
            self = .optIn(
                try OptIn(from: decoder)
            )
        }
    }
}

