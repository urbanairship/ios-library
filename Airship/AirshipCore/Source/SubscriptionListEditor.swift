/* Copyright Airship and Contributors */

import Foundation

/**
 * Subscription lists editor.
 */
@objc(UASubscriptionListsEditor)
public class SubscriptionListsEditor: NSObject {
    
    private var subscriptionListUpdates : [SubscriptionListUpdate] = []
    private let completionHandler : ([SubscriptionListUpdate]) -> Void

    @objc(initWithCompletionHandler:)
    public init(completionHandler: @escaping ([SubscriptionListUpdate]) -> Void) {
        self.completionHandler = completionHandler
        super.init()
    }
    
    /**
     *  Subscribes to a list.
     * - Parameters:
     *   - subscriptionListId: The subscription list identifier.
     */
    @objc(subscribe:)
    public func subscribe(subscriptionListId: String) {
        let subscriptionListUpdate = SubscriptionListUpdate(listId: subscriptionListId, type: .subscribe)
        subscriptionListUpdates.append(subscriptionListUpdate)
    }

    /**
     *  Unsubscribes from a list.
     * - Parameters:
     *   - subscriptionListId: The subscription list identifier.
     */
    @objc(unsubscribe:)
    public func unsubscribe(subscriptionListId: String) {
        let subscriptionListUpdate = SubscriptionListUpdate(listId: subscriptionListId, type: .unsubscribe)
        subscriptionListUpdates.append(subscriptionListUpdate)
    }

    /**
     * Applies subscription list changes.
     */
    @objc
    public func apply() {
        completionHandler(subscriptionListUpdates)
        subscriptionListUpdates.removeAll()
    }
}
