/* Copyright Airship and Contributors */

import Foundation

/**
 * Contact data.
 */
@objc(UAContactData)
public class ContactData : NSObject {
    
    /**
     * Subscription lists
     */
    @objc
    public let subscriptionLists: [String: ChannelScopes]
    
    /**
     * Tag groups.
     */
    @objc
    public let tags: [String: [String]]
    
    /**
     * Attributes.
     */
    @objc
    public let attributes: [String: Any]
    
    /**
     * Associated channels.
     */
    @objc
    public let channels: [AssociatedChannel]
    
    /**
     * Default constructor.
     * - Parameters:
     *   - tags: The tags.
     *   - attributes: The attributes.
     *   - subscriptionLists: The subscription lists.
     *   - channels: The associated channels.
     */
    @objc
    public init(tags: [String : [String]],
                attributes: [String : Any],
                channels: [AssociatedChannel],
                subscriptionLists: [String : ChannelScopes]) {

        self.tags = tags
        self.attributes = attributes
        self.channels = channels
        self.subscriptionLists = subscriptionLists
        super.init()
    }
}


