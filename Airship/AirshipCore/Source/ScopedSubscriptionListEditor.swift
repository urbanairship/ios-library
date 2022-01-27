/* Copyright Airship and Contributors */

import Foundation

/**
 * Scoped subscription list editor.
 */
@objc(UAScopedSubscriptionListEditor)
public class ScopedSubscriptionListEditor: NSObject {
    
    private var subscriptionListUpdates : [ScopedSubscriptionListUpdate] = []
    private let date : DateUtils
    private let completionHandler : ([ScopedSubscriptionListUpdate]) -> Void

    init(date: DateUtils, completionHandler: @escaping ([ScopedSubscriptionListUpdate]) -> Void) {
        self.date = date
        self.completionHandler = completionHandler
        super.init()
    }
    
    /**
     * Subscribes to a list.
     * - Parameters:
     *   - subscriptionListID: The subscription list identifier.
     *   - scope: Defines the channel types that the change applies to.
     */
    @objc(subscribe:scope:)
    public func subscribe(_ subscriptionListID: String, scope: ChannelScope) {
        let subscriptionListUpdate = ScopedSubscriptionListUpdate(listId: subscriptionListID,
                                                                  type: .subscribe,
                                                                  scope: scope,
                                                                  timestamp: self.date.now)
        subscriptionListUpdates.append(subscriptionListUpdate)
    }

    /**
     * Unsubscribes from a list.
     * - Parameters:
     *   - subscriptionListID: The subscription list identifier.
     *   - scope: Defines the channel types that the change applies to.
     */
    @objc(unsubscribe:scope:)
    public func unsubscribe(_ subscriptionListID: String, scope: ChannelScope) {
        let subscriptionListUpdate = ScopedSubscriptionListUpdate(listId: subscriptionListID,
                                                                  type: .unsubscribe,
                                                                  scope: scope,
                                                                  timestamp: date.now)
        subscriptionListUpdates.append(subscriptionListUpdate)
    }
    
    /**
     * Internal helper that uses a boolean flag to indicate whether to subscribe or unsubscribe.
     * - Parameters:
     *   - subscriptionListID: The subscription list identifier.
     *   - scope: Defines the channel types that the change applies to.
     *   - subscribe:`true` to subscribe, `false`to unsubscribe
     */
    public func mutate(_ subscriptionListID: String, scope: ChannelScope, subscribe: Bool) {
        if (subscribe) {
            self.subscribe(subscriptionListID, scope: scope)
        } else {
            self.unsubscribe(subscriptionListID, scope: scope)
        }
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
