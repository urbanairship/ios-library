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
    public let subscriptionLists: ScopedSubscriptionLists
    
    /**
     * Tag groups.
     */
    @objc
    public let tags: [String: [String]]
    
    /**
     * Attributes
     */
    @objc
    public let attributes: [String: Any]
    
    /**
     * Default constructor.
     * - Parameters:
     *   - tags: The tags.
     *   - attributes: The attributes.
     *   - subscriptionLists: The subscription lists.
     */
    @objc
    public init(tags: [String: [String]],
                attributes: [String: Any],
                subscriptionLists: ScopedSubscriptionLists) {
        self.tags = tags
        self.attributes = attributes
        self.subscriptionLists = subscriptionLists
        super.init()
    }
}


