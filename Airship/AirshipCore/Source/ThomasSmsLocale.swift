/* Copyright Airship and Contributors */

import Foundation

/// Locale configuration for a phone number
struct ThomasSMSLocale: ThomasSerializable {
    /// Country locale code (two letters)
    let countryCode: String
    
    /// Country phone code
    let prefix: String
    
    /// Registration info
    let registration: ThomasSMSRegistrationOption?

    enum CodingKeys: String, CodingKey {
        case countryCode = "country_code"
        case prefix
        case registration
    }
}

enum ThomasSMSRegistrationOption: ThomasSerializable, Hashable {
    case optIn(OptIn)

    struct OptIn: ThomasSerializable, Hashable {

        let type: RegistrationType = .optIn
        var senderID: String

        enum CodingKeys: String, CodingKey {
            case type
            case senderID = "sender_id"
        }
    }

    enum RegistrationType: String, Codable {
        case optIn = "opt_in"
    }

    private enum CodingKeys: String, CodingKey {
        case type
    }

    func encode(to encoder: any Encoder) throws {
        switch self {
        case .optIn(let properties):
            try properties.encode(to: encoder)
        }
    }

    init(from decoder: any Decoder) throws {
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

extension ThomasSMSRegistrationOption {
    func makeContactOptions(date: Date = Date.now) -> SMSRegistrationOptions {
        switch (self) {
        case .optIn(let properties):
            return .optIn(senderID: properties.senderID)
        }
    }
}
