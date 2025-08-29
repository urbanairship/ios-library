/* Copyright Airship and Contributors */

import Foundation

/// Contact data.
public struct ContactConflictEvent: Sendable, Equatable {

    /**
     * The named user ID if the conflict was caused by an identify operation with an existing named user through the SDK.
     */
    public let conflictingNamedUserID: String?

    /**
     * Subscription lists.
     */
    public let subscriptionLists: [String: [ChannelScope]]

    /**
     * Tag groups.
     */
    public let tags: [String: [String]]

    /**
     * Attributes.
     */
    public let attributes: [String: AirshipJSON]

    /**
     * Associated channels.
     */
    public let associatedChannels: [ChannelInfo]

    /**
     * Default constructor.
     * - Parameters:
     *   - tags: The tags.
     *   - attributes: The attributes.
     *   - subscriptionLists: The subscription lists.
     *   - channels: The associated channels.
     *   - conflictingNamedUserID: The conflicting named user ID.
     */
   init(
        tags: [String: [String]],
        attributes: [String: AirshipJSON],
        associatedChannels: [ChannelInfo],
        subscriptionLists: [String: [ChannelScope]],
        conflictingNamedUserID: String?
    ) {

        self.tags = tags
        self.associatedChannels = associatedChannels
        self.subscriptionLists = subscriptionLists
        self.conflictingNamedUserID = conflictingNamedUserID
        self.attributes = attributes
    }


    public struct ChannelInfo: Sendable, Equatable {

        /**
         * Channel type
         */
        public let channelType: ChannelType

        /**
         * channel ID
         */
        public let channelID: String

    }

}


