/* Copyright Airship and Contributors */

import Foundation

/// Associated channel data.
@objc(UAAssociatedChannel)
public final class AssociatedChannel: NSObject, Codable, Sendable {

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

    /**
     * The identifier: It can be the email address, the phone number or the open channel address
     */
    @objc
    public let identifier: String
    
    /**
     * The last registration date
     */
    @objc
    public let registrationDate: Date
    
    @objc
    public init(
        channelType: ChannelType,
        channelID: String,
        identifier: String,
        registrationDate: Date
    ) {
        self.channelType = channelType
        self.channelID = channelID
        self.identifier = identifier
        self.registrationDate = registrationDate
        super.init()
    }
}
