/* Copyright Airship and Contributors */

import Foundation

// NOTE: For internal use only. :nodoc:
enum OperationType : String, Codable {
    case update
    case identify
    case resolve
    case reset
}

// NOTE: For internal use only. :nodoc:
struct ContactOperation: Codable {
    let type: OperationType
    let payload: Any?
    
    
    enum CodingKeys: String, CodingKey {
        case payload = "payload"
        case type = "type"
    }
    
    
    private init(type: OperationType, payload: Any?) {
        self.type = type
        self.payload = payload
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        
        switch type {
        case .update:
            try container.encode(payload as! UpdatePayload, forKey: .payload)
        case .identify:
            try container.encode(payload as! IdentifyPayload, forKey: .payload)
        case .reset:
            try container.encodeNil(forKey: .payload)
        case .resolve:
            try container.encodeNil(forKey: .payload)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(OperationType.self, forKey: .type)

        switch type {
        case .update:
            self.payload = try container.decode(UpdatePayload.self, forKey: .payload)
        case .identify:
            self.payload = try container.decode(IdentifyPayload.self, forKey: .payload)
        case .resolve:
            self.payload = nil
        case .reset:
            self.payload = nil
        }
    }
    
    static func identify(identifier: String) -> ContactOperation {
        return ContactOperation(type: .identify, payload: IdentifyPayload(identifier: identifier))
    }
    
    static func update(tagUpdates: [TagGroupUpdate]) -> ContactOperation {
        return ContactOperation(type: .update, payload: UpdatePayload(tagUpdates: tagUpdates))
    }
    
    static func update(attributeUpdates: [AttributeUpdate]) -> ContactOperation {
        return ContactOperation(type: .update, payload: UpdatePayload(attrubuteUpdates: attributeUpdates))
    }
    
    static func update(subscriptionListsUpdates: [ScopedSubscriptionListUpdate]) -> ContactOperation {
        return ContactOperation(type: .update, payload: UpdatePayload(subscriptionListsUpdates: subscriptionListsUpdates))
    }
    
    static func update(tagUpdates: [TagGroupUpdate]?, attributeUpdates: [AttributeUpdate]?, subscriptionListUpdates: [ScopedSubscriptionListUpdate]? = nil) -> ContactOperation {
        return ContactOperation(type: .update, payload: UpdatePayload(tagUpdates: tagUpdates,
                                                                      attrubuteUpdates: attributeUpdates,
                                                                     subscriptionListsUpdates: subscriptionListUpdates))
    }
    
    static func reset() -> ContactOperation {
        return ContactOperation(type: .reset, payload: nil)
    }
    
    static func resolve() -> ContactOperation {
        return ContactOperation(type: .resolve, payload: nil)
    }
}

struct UpdatePayload : Codable {
    var tagUpdates: [TagGroupUpdate]?
    var attrubuteUpdates: [AttributeUpdate]?
    var subscriptionListsUpdates: [ScopedSubscriptionListUpdate]?
}

struct IdentifyPayload : Codable {
    var identifier: String
}

