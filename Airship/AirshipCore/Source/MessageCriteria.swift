/* Copyright Airship and Contributors */

import Foundation

struct MessageCriteria: Codable, Sendable, Equatable {
    let messageTypePredicate: JSONPredicate?
    let campaignsPredicate: JSONPredicate?
    
    enum CodingKeys: String, CodingKey {
        case messageTypePredicate = "message_type"
        case campaignsPredicate = "campaigns"
    }
}
