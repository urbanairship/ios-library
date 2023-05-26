/* Copyright Airship and Contributors */

import Foundation

struct MessageCriteria: Codable, Sendable {
    let messageTypePredicate: JSONPredicate?
    
    enum CodingKeys: String, CodingKey {
        case messageTypePredicate = "message_type"
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        if
            let json = try values.decodeIfPresent(AirshipJSON.self, forKey: .messageTypePredicate),
            let predicate = JSONPredicate.from(json)
        {
            self.messageTypePredicate = predicate
        } else {
            self.messageTypePredicate = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        if let predicate = messageTypePredicate {
            try container.encode(AirshipJSON.wrap(predicate.payload()), forKey: .messageTypePredicate)
        }
    }
}

extension JSONPredicate {
    static func from(_ json: AirshipJSON) -> JSONPredicate? {
        switch json {
        case .object:
            return try? JSONPredicate(json: json.unWrap())
        default:
            return nil
        }
    }
}
