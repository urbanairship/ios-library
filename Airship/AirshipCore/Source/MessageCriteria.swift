/* Copyright Airship and Contributors */

import Foundation

struct MessageCriteria: Codable, Sendable {
    let messageTypePredicate: JSONPredicate?
    
    enum CodingKeys: String, CodingKey {
        case messageTypePredicate = "message_type"
    }
}
