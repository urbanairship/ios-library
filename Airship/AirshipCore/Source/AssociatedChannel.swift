/* Copyright Airship and Contributors */

import Foundation

public enum AssociatedChannelType: Hashable, Sendable {
    case sms(SMSAssociatedChannel)
    case email(EmailAssociatedChannel)
    case open(AssociatedChannel)
}

/// Associated channel data.
@objc(UAAssociatedChannel)
public class AssociatedChannel: NSObject, Codable, @unchecked Sendable {

    /**
     * Channel type
     */
    @objc
    public let channelType: ChannelType

    /**
     * channel ID
     */
    @objc
    public let channelID: String
    
    @objc
    public init(
        channelType: ChannelType,
        channelID: String
    ) {
        self.channelType = channelType
        self.channelID = channelID
        super.init()
    }
}

@objc(UAEmailAssociatedChannel)
public final class EmailAssociatedChannel: AssociatedChannel, @unchecked Sendable {
    
    @objc
    public let address: String
    
    @objc
    public let commercialOptedIn: Date?

    @objc
    public let commercialOptedOut: Date?
    
    @objc
    public let transactionalOptedIn: Date?
    
    @objc
    public init(
        channelID: String,
        address: String,
        commercialOptedIn: Date?,
        commercialOptedOut: Date?,
        transactionalOptedIn: Date?
    ) {
        self.address = address
        self.commercialOptedIn = commercialOptedIn
        self.commercialOptedOut = commercialOptedOut
        self.transactionalOptedIn = transactionalOptedIn
        
        super.init(channelType: .email, channelID: channelID)
    }
    
    required init(from decoder: any Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }
}

@objc(UASMSAssociatedChannel)
public final class SMSAssociatedChannel: AssociatedChannel, @unchecked Sendable {
    
    @objc
    public let msisdn: String
    
    @objc
    public let optIn: Bool
    
    @objc
    public init(
        channelID: String,
        msisdn: String,
        optIn: Bool
    ) {
        self.msisdn = msisdn
        self.optIn = optIn
        
        super.init(channelType: .sms, channelID: channelID)
    }
    
    required init(from decoder: any Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }
}


