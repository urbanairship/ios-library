/* Copyright Airship and Contributors */

import Foundation

/**
 * Subscription list editor.
 */
@objc(UASubscriptionListEditor)
public class SubscriptionListEditor: NSObject {
    
    private var subscriptionListUpdates : [SubscriptionListUpdate] = []
    private let completionHandler : ([SubscriptionListUpdate]) -> Void

    init(completionHandler: @escaping ([SubscriptionListUpdate]) -> Void) {
        self.completionHandler = completionHandler
        super.init()
    }
    
    /**
     * Subscribes to a list.
     * - Parameters:
     *   - subscriptionListID: The subscription list identifier.
     */
    @objc(subscribe:)
    public func subscribe(_ subscriptionListID: String) {
        let subscriptionListUpdate = SubscriptionListUpdate(listId: subscriptionListID, type: .subscribe)
        subscriptionListUpdates.append(subscriptionListUpdate)
    }

    /**
     * Unsubscribes from a list.
     * - Parameters:
     *   - subscriptionListID: The subscription list identifier.
     */
    @objc(unsubscribe:)
    public func unsubscribe(_ subscriptionListID: String) {
        let subscriptionListUpdate = SubscriptionListUpdate(listId: subscriptionListID, type: .unsubscribe)
        subscriptionListUpdates.append(subscriptionListUpdate)
    }

    /**
     * Applies subscription list changes.
     */
    @objc
    public func apply() {
        completionHandler(AudienceUtils.collapse(subscriptionListUpdates))
        subscriptionListUpdates.removeAll()
    }
}
