import Foundation
import AirshipCore

@objc
public class OUAScopedSubscriptionListEditor: NSObject {
    
    var editor: ScopedSubscriptionListEditor?
    
    /**
     * Subscribes to a list.
     * - Parameters:
     *   - subscriptionListID: The subscription list identifier.
     *   - scope: Defines the channel types that the change applies to.
     */
    @objc(subscribe:scope:)
    public func subscribe(_ subscriptionListID: String, scope: ChannelScope) {
        self.editor?.subscribe(subscriptionListID, scope: scope)
    }

    /**
     * Unsubscribes from a list.
     * - Parameters:
     *   - subscriptionListID: The subscription list identifier.
     *   - scope: Defines the channel types that the change applies to.
     */
    @objc(unsubscribe:scope:)
    public func unsubscribe(_ subscriptionListID: String, scope: ChannelScope) {
        self.editor?.unsubscribe(subscriptionListID, scope: scope)
    }

    /**
     * Applies subscription list changes.
     */
    @objc
    public func apply() {
        self.editor?.apply()
    }
}
    
