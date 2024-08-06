/* Copyright Airship and Contributors */

import Foundation
import AirshipCore

@objc
public class OUASubscriptionListEditor: NSObject {
    
    var editor: SubscriptionListEditor?
    
    /**
     * Subscribes to a list.
     * - Parameters:
     *   - subscriptionListID: The subscription list identifier.
     */
    @objc(subscribe:)
    public func subscribe(_ subscriptionListID: String) {
        self.editor?.subscribe(subscriptionListID)
    }
    
    /**
     * Unsubscribes from a list.
     * - Parameters:
     *   - subscriptionListID: The subscription list identifier.
     */
    @objc(unsubscribe:)
    public func unsubscribe(_ subscriptionListID: String) {
        self.editor?.unsubscribe(subscriptionListID)
    }
    
    /**
     * Applies subscription list changes.
     */
    @objc
    public func apply() {
        self.editor?.apply()
    }
    
}
