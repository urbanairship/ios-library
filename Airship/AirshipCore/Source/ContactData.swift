/* Copyright Airship and Contributors */

import Foundation

/**
 * Contact data.
 */
@objc(UAContactData)
public class ContactData : NSObject {
    
    /**
     * Tag groups.
     */
    @objc
    public let tags: [String : [String]]
    
    /**
     * Attributes
     */
    @objc
    public let attributes: [String : Any]
    
    /**
     * Default constructor.
     * - Parameters:
     *   - tags: The tags.
     *   - attributes: The attributes.
     */
    @objc
    public init(tags: [String : [String]], attributes: [String : Any]) {
        self.tags = tags
        self.attributes = attributes
        super.init()
    }
}


