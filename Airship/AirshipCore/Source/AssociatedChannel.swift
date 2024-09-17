/* Copyright Airship and Contributors */

import Foundation

/// Associated channel data.
@available(*, deprecated, message: "Use ContactConflictEvent.ChannelInfo instead")
public final class AssociatedChannel: NSObject, Codable, Sendable {

    /**
     * Channel type
     */
    public let channelType: ChannelType

    /**
     * channel ID
     */
    public let channelID: String


    public init(channelType: ChannelType, channelID: String) {
        self.channelType = channelType
        self.channelID = channelID
        super.init()
    }
}
