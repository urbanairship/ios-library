/* Copyright Airship and Contributors */

import Foundation

public enum RegistrationOptions: Sendable, Equatable, Codable {
    case email(String, EmailRegistrationOptions)
    case sms(String, SMSRegistrationOptions)
    case open
}

enum AssociatedChannelType: String, Codable, Equatable, Sendable {
    case sms
    case email
    case open
}

public indirect enum AssociatedChannel: Codable, Hashable, Equatable, Sendable {
    case sms(SMSAssociatedChannel)
    case email(EmailAssociatedChannel)
    case open(BasicAssociatedChannel)

    enum CodingKeys: String, CodingKey {
        case type = "type"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(
            AssociatedChannelType.self,
            forKey: .type
        )
        let singleValueContainer = try decoder.singleValueContainer()

        switch type {
        case .sms:
            self = .sms(
                try singleValueContainer.decode(SMSAssociatedChannel.self)
            )
        case .email:
            self = .email(
                try singleValueContainer.decode(EmailAssociatedChannel.self)
            )
        case .open:
            self = .open(
                try singleValueContainer.decode(BasicAssociatedChannel.self)
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let content: Encodable
        
        switch self {
        case .sms(let model):
            content = model
        case .email(let model):
            content = model
        case .open(let model):
            content = model
        }
        
        try container.encode(content)
    }
}

public protocol AssociatedChannelProtocol: Codable, Equatable, Sendable {
    var channelID: String { get }
}

@objc(UABasicAssociatedChannel)
public class BasicAssociatedChannel: NSObject, AssociatedChannelProtocol, @unchecked Sendable {

    /**
     * Channel ID
     */
    @objc
    public let channelID: String
        
    @objc
    public init(
        channelID: String
    ) {
        self.channelID = channelID
        super.init()
    }
    
    enum CodingKeys: String, CodingKey {
        case channelID = "channel_id"
    }
}

@objc(UAEmailAssociatedChannel)
public class EmailAssociatedChannel: NSObject, AssociatedChannelProtocol, @unchecked Sendable {
    
    @objc
    public var channelID: String
    
    @objc
    public let address: String
        
    public let transactionalOptedIn: Date?
    
    public let commercialOptedIn: Date?
    
    @objc
    public init(
        channelID: String,
        address: String,
        transactionalOptedIn: Date?,
        commercialOptedIn: Date?
    ) {
        self.channelID = channelID
        self.address = address
        self.transactionalOptedIn = transactionalOptedIn
        self.commercialOptedIn = commercialOptedIn
    }
    
    enum CodingKeys: String, CodingKey {
        case channelID = "channel_id"
        case address = "email_address"
        case transactionalOptedIn = "transactional_opted_in"
        case commercialOptedIn = "commercial_opted_in"
    }
}

@objc(UASMSAssociatedChannel)
public class SMSAssociatedChannel: NSObject, AssociatedChannelProtocol, @unchecked Sendable {
    
    @objc
    public var channelID: String
    
    @objc
    public var optIn: Bool
    
    @objc
    public let msisdn: String
    
    @objc
    public let sender: String
    
    @objc
    public init(
        channelID: String,
        msisdn: String,
        sender: String,
        optIn: Bool
    ) {
        self.channelID = channelID
        self.msisdn = msisdn
        self.sender = sender
        self.optIn = optIn
    }
    
    enum CodingKeys: String, CodingKey {
        case channelID = "channel_id"
        case optIn = "opt_in"
        case msisdn = "msisdn"
        case sender = "sender"
    }
}


