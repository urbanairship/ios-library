/* Copyright Airship and Contributors */

import Foundation

/// Subscription list editor.
public class SubscriptionListEditor {

    private var subscriptionListUpdates: [SubscriptionListUpdate] = []
    private let completionHandler: ([SubscriptionListUpdate]) -> Void

    init(completionHandler: @escaping ([SubscriptionListUpdate]) -> Void) {
        self.completionHandler = completionHandler
    }

    /**
     * Subscribes to a list.
     * - Parameters:
     *   - subscriptionListID: The subscription list identifier.
     */
    public func subscribe(_ subscriptionListID: String) {
        let subscriptionListUpdate = SubscriptionListUpdate(
            listId: subscriptionListID,
            type: .subscribe
        )
        subscriptionListUpdates.append(subscriptionListUpdate)
    }

    /**
     * Unsubscribes from a list.
     * - Parameters:
     *   - subscriptionListID: The subscription list identifier.
     */
    public func unsubscribe(_ subscriptionListID: String) {
        let subscriptionListUpdate = SubscriptionListUpdate(
            listId: subscriptionListID,
            type: .unsubscribe
        )
        subscriptionListUpdates.append(subscriptionListUpdate)
    }

    /**
     * Applies subscription list changes.
     */
    public func apply() {
        completionHandler(AudienceUtils.collapse(subscriptionListUpdates))
        subscriptionListUpdates.removeAll()
    }
}
