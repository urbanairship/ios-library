/* Copyright Airship and Contributors */

import Combine
import Foundation
import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Preference Center State
public class PreferenceCenterState: ObservableObject {

    /// The config
    public let config: PreferenceCenterConfig

    private var contactSubscriptions: [String: Set<ChannelScope>]
    private var channelSubscriptions: Set<String>
    private var channelUpdates: AnyCancellable?
    private var contactUpdates: AnyCancellable?
    private let subscriber: PreferenceSubscriber

    /// Default constructor.
    /// - Parameters:
    ///     - config: The preference config
    ///     - contactSubscriptions: The relavent contact subscriptions
    ///     - channelSubscriptions: The relavent channel subscriptions.
    public convenience init(
        config: PreferenceCenterConfig,
        contactSubscriptions: [String: Set<ChannelScope>] = [:],
        channelSubscriptions: Set<String> = Set()
    ) {

        self.init(
            config: config,
            contactSubscriptions: contactSubscriptions,
            channelSubscriptions: channelSubscriptions,
            subscriber: PreferenceCenterState.makeSubscriber()
        )
    }

    init(
        config: PreferenceCenterConfig,
        contactSubscriptions: [String: Set<ChannelScope>] = [:],
        channelSubscriptions: Set<String> = Set(),
        subscriber: PreferenceSubscriber
    ) {

        self.config = config
        self.contactSubscriptions = contactSubscriptions
        self.channelSubscriptions = channelSubscriptions
        self.subscriber = subscriber

        self.subscribeToUpdates()
    }

    /// Subscribes to updates from the Airship instance
    private func subscribeToUpdates() {
        self.channelUpdates = self.subscriber.channelSubscriptionListEdits
            .sink { edit in
                self.processChannelEdit(edit)
            }

        self.contactUpdates = self.subscriber.contactSubscriptionListEdits
            .sink { edit in
                self.processContactEdit(edit)
            }
    }

    /// Checks if the channel is subscribed to the preference state
    /// - Parameters:
    ///     - listID: The preference list ID
    /// - Returns: true if any of the channel is subscribed, otherwise false.
    public func isChannelSubscribed(_ listID: String) -> Bool {
        return self.channelSubscriptions.contains(listID)
    }

    /// Checks if the contact is subscribed to the preference state
    /// - Parameters:
    ///     - listID: The preference list ID
    ///     - scope: The channel scope
    /// - Returns: true if any the contact is subscribed for that scope, otherwise false.
    public func isContactSubscribed(_ listID: String, scope: ChannelScope)
        -> Bool
    {
        let containsSubscription = self.contactSubscriptions[listID]?
            .contains {
                $0 == scope
            }

        if containsSubscription == true {
            return true
        }

        if config.options?.mergeChannelDataToContact == true && scope == .app {
            return isChannelSubscribed(listID)
        }

        return false
    }

    /// Checks if the contact is subscribed to the preference state
    /// - Parameters:
    ///     - listID: The preference list ID
    ///     - scopes: The channel scopes
    /// - Returns: true if the contact is subscribed to any of the scopes, otherwise false.
    public func isContactSubscribed(_ listID: String, scopes: [ChannelScope])
        -> Bool
    {
        return scopes.contains { scope in
            isContactSubscribed(listID, scope: scope)
        }
    }

    /// Creates a channel subscription binding for the list ID.
    /// - Parameters:
    ///     - channelListID: The subscription list ID
    /// - Returns: A subscription binding
    public func makeBinding(channelListID: String) -> Binding<Bool> {
        return Binding<Bool>(
            get: { self.isChannelSubscribed(channelListID) },
            set: { subscribe in
                self.subscriber.updateChannelSubscription(
                    channelListID,
                    subscribe: subscribe
                )
            }
        )
    }

    /// Creates a contact subscription binding for the list ID and scopes.
    /// - Parameters:
    ///     - contactListID: The subscription list ID
    ///     - scopes: The subscription list scopes
    /// - Returns: A subscription binding
    public func makeBinding(
        contactListID: String,
        scopes: [ChannelScope]
    ) -> Binding<Bool> {

        return Binding<Bool>(
            get: {
                self.isContactSubscribed(contactListID, scopes: scopes)
            },
            set: { subscribe in
                self.subscriber.updateContactSubscription(
                    contactListID,
                    scopes: scopes,
                    subscribe: subscribe
                )
            }
        )
    }

    private func processContactEdit(_ edit: ScopedSubscriptionListEdit) {
        self.objectWillChange.send()

        switch edit {
        case .subscribe(let listID, let scope):
            var scopes =
                self.contactSubscriptions[listID] ?? Set<ChannelScope>()
            scopes.insert(scope)
            self.contactSubscriptions[listID] = scopes
        case .unsubscribe(let listID, let scope):
            if var scopes = self.contactSubscriptions[listID] {
                scopes.remove(scope)
                if scopes.isEmpty {
                    self.contactSubscriptions[listID] = nil
                } else {
                    self.contactSubscriptions[listID] = scopes
                }
            }
        }
    }

    private func processChannelEdit(_ edit: SubscriptionListEdit) {
        self.objectWillChange.send()

        switch edit {
        case .subscribe(let listID):
            self.channelSubscriptions.insert(listID)
        case .unsubscribe(let listID):
            self.channelSubscriptions.remove(listID)
        }
    }

    static func makeSubscriber() -> PreferenceSubscriber {
        guard Airship.isFlying else {
            return PreviewPreferenceSubscriber()
        }
        return AirshipPreferenceSubscriber()
    }
}

protocol PreferenceSubscriber {
    var channelSubscriptionListEdits: AnyPublisher<SubscriptionListEdit, Never>
    {
        get
    }
    var contactSubscriptionListEdits:
        AnyPublisher<ScopedSubscriptionListEdit, Never>
    { get }

    func updateChannelSubscription(
        _ listID: String,
        subscribe: Bool
    )

    func updateContactSubscription(
        _ listID: String,
        scopes: [ChannelScope],
        subscribe: Bool
    )
}

class PreviewPreferenceSubscriber: PreferenceSubscriber {
    private let channelEditsSubject = PassthroughSubject<
        SubscriptionListEdit, Never
    >()
    var channelSubscriptionListEdits: AnyPublisher<SubscriptionListEdit, Never>
    {
        return channelEditsSubject.eraseToAnyPublisher()
    }

    private let contactEditsSubject = PassthroughSubject<
        ScopedSubscriptionListEdit, Never
    >()
    var contactSubscriptionListEdits:
        AnyPublisher<ScopedSubscriptionListEdit, Never>
    {
        return contactEditsSubject.eraseToAnyPublisher()
    }

    func updateChannelSubscription(_ listID: String, subscribe: Bool) {
        if subscribe {
            channelEditsSubject.send(.subscribe(listID))
        } else {
            channelEditsSubject.send(.unsubscribe(listID))
        }
    }

    func updateContactSubscription(
        _ listID: String,
        scopes: [ChannelScope],
        subscribe: Bool
    ) {
        scopes.forEach { scope in
            if subscribe {
                contactEditsSubject.send(.subscribe(listID, scope))
            } else {
                contactEditsSubject.send(.unsubscribe(listID, scope))
            }
        }
    }
}

class AirshipPreferenceSubscriber: PreferenceSubscriber {
    var channelSubscriptionListEdits: AnyPublisher<SubscriptionListEdit, Never>
    {
        return Airship.channel.subscriptionListEdits
    }

    var contactSubscriptionListEdits:
        AnyPublisher<ScopedSubscriptionListEdit, Never>
    {
        return Airship.contact.subscriptionListEdits
    }

    func updateChannelSubscription(_ listID: String, subscribe: Bool) {
        Airship.channel.editSubscriptionLists { editor in
            if subscribe {
                editor.subscribe(listID)
            } else {
                editor.unsubscribe(listID)
            }
        }
    }

    func updateContactSubscription(
        _ listID: String,
        scopes: [ChannelScope],
        subscribe: Bool
    ) {
        Airship.contact.editSubscriptionLists { editor in
            editor.mutate(
                listID,
                scopes: scopes,
                subscribe: subscribe
            )
        }
    }
}
