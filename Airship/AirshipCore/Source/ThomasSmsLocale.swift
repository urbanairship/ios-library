/* Copyright Airship and Contributors */

import Foundation

/// Locale configuration for a phone number
struct ThomasSmsLocale: ThomasSerializable {
    /// Country locale code (two letters)
    let countryCode: String
    
    /// Country phone code
    let prefix: String
    
    /// Registration info
    let registration: ThomasSmsLocaleRegistration?
    
    
    enum CodingKeys: String, CodingKey {
        case countryCode = "country_code"
        case prefix
        case registration
    }
}

/// Phone number sender info
struct ThomasSmsLocaleRegistration: ThomasSerializable, Hashable {

    /// Registration type
    let type: RegistrationType
    
    /// Sender ID
    let senderId: String
    
    enum CodingKeys: String, CodingKey {
        case type
        case senderId = "sender_id"
    }
    
    enum RegistrationType: String, ThomasSerializable, Hashable {
        case optIn = "opt_in"
    }
}
