/* Copyright Airship and Contributors */

import Foundation

/// Contact data.
@objc(UAContactConflictEvent)
public final class ContactConflictEvent: NSObject, @unchecked Sendable {

    /**
     * The named user ID if the conflict was caused by an identify operation with an existing named user through the SDK.
     */
    @objc
    public let conflictingNamedUserID: String?

    /**
     * Subscription lists.
     */
    public let subscriptionLists: [String: [ChannelScope]]

    /**
     * Subscription lists.
     */
    @objc(subscriptionLists)
    public var _subscriptionLists: [String: ChannelScopes] {
        return self.subscriptionLists.mapValues { ChannelScopes($0) }
    }

    /**
     * Tag groups.
     */
    @objc
    public let tags: [String: [String]]

    /**
     * Attributes.
     */
    @objc
    public let attributes: [String: AnyHashable]

    /**
     * Associated channels.
     * @deprecated
     */
    @objc
    @available(*, deprecated, message: "Use associatedChannels instead")
    public var channels: [AssociatedChannel] {
        associatedChannels.map { info in
            AssociatedChannel(channelType: info.channelType, channelID: info.channelID)
        }
    }

    /**
     * Associated channels.
     */
    @objc
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
        self.attributes = attributes.compactMapValues { $0.unWrap() }
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? ContactConflictEvent else {
            return false
        }

        return self.tags == other.tags &&
        self.attributes == other.attributes &&
        self.subscriptionLists == other.subscriptionLists &&
        self.conflictingNamedUserID == other.conflictingNamedUserID &&
        self.associatedChannels == other.associatedChannels
    }

    public override var hash: Int {
        var result = 1
        result = 31 * result + tags.hashValue
        result = 31 * result + attributes.hashValue
        result = 31 * result + subscriptionLists.hashValue
        result = 31 * result + conflictingNamedUserID.hashValue
        result = 31 * result + associatedChannels.hashValue
        return result
    }

    @objc(UAContactConflictEventChannelInfo)
    public final class ChannelInfo: NSObject, Codable, Sendable {

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

}


