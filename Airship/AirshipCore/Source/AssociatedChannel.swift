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

    @objc
    public init(channelType: ChannelType, channelID: String) {
        self.channelType = channelType
        self.channelID = channelID
        super.init()
    }
}
