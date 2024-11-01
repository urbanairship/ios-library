/* Copyright Airship and Contributors */

import Foundation

/// Scoped subscription list editor.
public class ScopedSubscriptionListEditor {

    private var subscriptionListUpdates: [ScopedSubscriptionListUpdate] = []
    private let date: AirshipDateProtocol
    private let completionHandler: ([ScopedSubscriptionListUpdate]) -> Void

    init(
        date: AirshipDateProtocol,
        completionHandler: @escaping ([ScopedSubscriptionListUpdate]) -> Void
    ) {
        self.date = date
        self.completionHandler = completionHandler
    }

    /**
     * Subscribes to a list.
     * - Parameters:
     *   - subscriptionListID: The subscription list identifier.
     *   - scope: Defines the channel types that the change applies to.
     */
    public func subscribe(_ subscriptionListID: String, scope: ChannelScope) {
        let subscriptionListUpdate = ScopedSubscriptionListUpdate(
            listId: subscriptionListID,
            type: .subscribe,
            scope: scope,
            date: self.date.now
        )
        subscriptionListUpdates.append(subscriptionListUpdate)
    }

    /**
     * Unsubscribes from a list.
     * - Parameters:
     *   - subscriptionListID: The subscription list identifier.
     *   - scope: Defines the channel types that the change applies to.
     */
    public func unsubscribe(_ subscriptionListID: String, scope: ChannelScope) {
        let subscriptionListUpdate = ScopedSubscriptionListUpdate(
            listId: subscriptionListID,
            type: .unsubscribe,
            scope: scope,
            date: date.now
        )
        subscriptionListUpdates.append(subscriptionListUpdate)
    }

    /**
     * Internal helper that uses a boolean flag to indicate whether to subscribe or unsubscribe.
     * - Parameters:
     *   - subscriptionListID: The subscription list identifier.
     *   - scopes: The scopes.
     *   - subscribe:`true` to subscribe, `false`to unsubscribe
     */
    public func mutate(
        _ subscriptionListID: String,
        scopes: [ChannelScope],
        subscribe: Bool
    ) {
        if subscribe {
            scopes.forEach { self.subscribe(subscriptionListID, scope: $0) }
        } else {
            scopes.forEach { self.unsubscribe(subscriptionListID, scope: $0) }
        }
    }

    /**
     * Applies subscription list changes.
     */
    public func apply() {
        completionHandler(subscriptionListUpdates)
        subscriptionListUpdates.removeAll()
    }
}
