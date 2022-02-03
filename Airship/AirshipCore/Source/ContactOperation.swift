/* Copyright Airship and Contributors */

import Foundation

// NOTE: For internal use only. :nodoc:
enum OperationType : String, Codable {
    case update
    case identify
    case resolve
    case reset
    case registerEmail
    case registerSMS
    case registerOpen
    case associateChannel
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
        case .registerEmail:
            try container.encode(payload as! RegisterEmailPayload, forKey: .payload)
        case .registerSMS:
            try container.encode(payload as! RegisterSMSPayload, forKey: .payload)
        case .registerOpen:
            try container.encode(payload as! RegisterOpenPayload, forKey: .payload)
        case .associateChannel:
            try container.encode(payload as! AssociateChannelPayload, forKey: .payload)
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
        case .registerEmail:
            self.payload = try container.decode(RegisterEmailPayload.self, forKey: .payload)
        case .registerSMS:
            self.payload = try container.decode(RegisterSMSPayload.self, forKey: .payload)
        case .registerOpen:
            self.payload = try container.decode(RegisterOpenPayload.self, forKey: .payload)
        case .associateChannel:
            self.payload = try container.decode(AssociateChannelPayload.self, forKey: .payload)
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
        
    static func registerEmail(_ address: String, options: EmailRegistrationOptions) -> ContactOperation {
            return ContactOperation(type: .registerEmail, payload: RegisterEmailPayload(address: address, options: options))
    }
    
    static func registerSMS(_ msisdn: String, options: SMSRegistrationOptions) -> ContactOperation {
        return ContactOperation(type: .registerSMS, payload: RegisterSMSPayload(msisdn: msisdn, options: options))
    }
    
    static func registerOpen(_ address: String, options: OpenRegistrationOptions) -> ContactOperation {
        return ContactOperation(type: .registerOpen, payload: RegisterOpenPayload(address: address, options: options))
    }
    
    static func associateChannel(_ channelID: String, type: ChannelType) -> ContactOperation {
        return ContactOperation(type: .associateChannel, payload: AssociateChannelPayload(channelID: channelID, channelType: type))
    }
}

struct UpdatePayload : Codable {
    var tagUpdates: [TagGroupUpdate]?
    var attrubuteUpdates: [AttributeUpdate]?
    var subscriptionListsUpdates: [ScopedSubscriptionListUpdate]?
}

struct RegisterEmailPayload : Codable {
    var address: String
    var options: EmailRegistrationOptions
}

struct RegisterSMSPayload : Codable {
    var msisdn: String
    var options: SMSRegistrationOptions
}

struct RegisterOpenPayload : Codable {
    var address: String
    var options: OpenRegistrationOptions
}

struct IdentifyPayload : Codable {
    var identifier: String
}

struct AssociateChannelPayload : Codable {
    var channelID: String
    var channelType: ChannelType
}

