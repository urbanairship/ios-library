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
    private var channelsList: Set<AssociatedChannelType>
    private var subscriptions: Set<AnyCancellable> = []
    private let subscriber: PreferenceSubscriber

    private let channelAssociationSubject = PassthroughSubject<[AssociatedChannelType], Never>()
    public var channelAssociationPublisher: AnyPublisher<[AssociatedChannelType], Never>
    {
        return channelAssociationSubject.eraseToAnyPublisher()
    }
    
    /// Default constructor.
    /// - Parameters:
    ///     - config: The preference config
    ///     - contactSubscriptions: The relavent contact subscriptions
    ///     - channelSubscriptions: The relavent channel subscriptions.
    ///     - channelsLists: The relavant channels list.
    public convenience init(
        config: PreferenceCenterConfig,
        contactSubscriptions: [String: Set<ChannelScope>] = [:],
        channelSubscriptions: Set<String> = Set(),
        channelsList: Set<AssociatedChannelType> = Set()
    ) {

        self.init(
            config: config,
            contactSubscriptions: contactSubscriptions,
            channelSubscriptions: channelSubscriptions,
            channelsList: channelsList,
            subscriber: PreferenceCenterState.makeSubscriber()
        )
    }

    init(
        config: PreferenceCenterConfig,
        contactSubscriptions: [String: Set<ChannelScope>] = [:],
        channelSubscriptions: Set<String> = Set(),
        channelsList: Set<AssociatedChannelType> = Set(),
        subscriber: PreferenceSubscriber
    ) {
        self.config = config
        self.contactSubscriptions = contactSubscriptions
        self.channelSubscriptions = channelSubscriptions
        self.channelsList = channelsList
        self.subscriber = subscriber

        self.subscribeToUpdates()
    }

    /// Subscribes to updates from the Airship instance
    private func subscribeToUpdates() {
        self.subscriber.channelSubscriptionListEdits
            .sink { edit in
                self.processChannelEdit(edit)
            }
            .store(in: &subscriptions)

        self.subscriber.contactSubscriptionListEdits
            .sink { edit in
                self.processContactEdit(edit)
            }
            .store(in: &subscriptions)
        
        self.subscriber.channelAssociationPublisher
            .sink { edit in
                self.processChannelAssociation(edit)
            }
            .store(in: &subscriptions)
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
#if canImport(AirshipCore)
        @unknown default:
            AirshipLogger.error("Unknown scooped subscription list edit \(edit)")
#endif
        }
    }

    private func processChannelEdit(_ edit: SubscriptionListEdit) {
        self.objectWillChange.send()

        switch edit {
        case .subscribe(let listID):
            self.channelSubscriptions.insert(listID)
        case .unsubscribe(let listID):
            self.channelSubscriptions.remove(listID)
#if canImport(AirshipCore)
        @unknown default:
            AirshipLogger.error("Unknown subscription list edit \(edit)")
#endif
        }
    }
    
    private func processChannelAssociation(
        _ state: ChannelRegistrationState
    ) {
        switch state {
        case .failed:
            AirshipLogger.error("Registration channel failed")
        case .succeed(let channelRegistrationType):
            switch channelRegistrationType {
            case .optIn(let channel):
                self.channelsList.insert(channel)
            case .optOut(let channelID):
                let channel = self.channelsList.filter { channel in
                    if case .sms(let associatedChannel) = channel {
                        return associatedChannel.channelID == channelID
                    } else if case .email(let associatedChannel) = channel {
                        return associatedChannel.channelID == channelID
                    }
                    return false
                }
                if let channel = channel.first {
                    self.channelsList.remove(channel)
                }
    #if canImport(AirshipCore)
            @unknown default:
                AirshipLogger.error("Unknown channel registration type")
    #endif
            }
    #if canImport(AirshipCore)
        @unknown default:
            AirshipLogger.error("Unknown channel registration state")
    #endif
        }
        self.channelAssociationSubject.send(Array(self.channelsList))
    }
    
    static func makeSubscriber() -> PreferenceSubscriber {
        guard Airship.isFlying else {
            return PreviewPreferenceSubscriber()
        }
        return AirshipPreferenceSubscriber()
    }
    
}

protocol PreferenceSubscriber {
    
    var channelSubscriptionListEdits: AnyPublisher<SubscriptionListEdit, Never> { get }
    var contactSubscriptionListEdits: AnyPublisher<ScopedSubscriptionListEdit, Never> { get }
    var channelAssociationPublisher: AnyPublisher<ChannelRegistrationState, Never> { get }
    
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

    private let channelAssociationSubject = PassthroughSubject<ChannelRegistrationState, Never>()
    var channelAssociationPublisher: AnyPublisher<ChannelRegistrationState, Never>
    {
        return channelAssociationSubject.eraseToAnyPublisher()
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
    
    var channelAssociationPublisher: AnyPublisher<ChannelRegistrationState, Never>
    {
        return Airship.contact.channelRegistrationEditPublisher
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
