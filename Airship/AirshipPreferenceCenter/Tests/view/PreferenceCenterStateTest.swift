/* Copyright Airship and Contributors */

import Testing
import AirshipCore
import Combine
import SwiftUI

@testable
import AirshipPreferenceCenter

@Suite("Preference Center State")
struct PreferenceCenterStateTest {
    let subscriber = TestPreferenceSubscriber()
    let state: PreferenceCenterState!

    @MainActor
    init() {
        state = PreferenceCenterState(
            config: PreferenceCenterConfig(
                identifier: "empty",
                sections: []
            ),
            contactSubscriptions: [
                "baz": [.app]
            ],
            channelSubscriptions: ["foo", "bar"],
            subscriber: subscriber
        )
    }

    @MainActor
    @Test
    func channelBinding() {
        let channelFoo = self.state.makeBinding(channelListID: "foo")
        #expect(channelFoo.wrappedValue)

        channelFoo.wrappedValue.toggle()
        #expect(!channelFoo.wrappedValue)
        #expect([.unsubscribe("foo")] == self.subscriber.channelEdits)

        channelFoo.wrappedValue.toggle()
        #expect([.unsubscribe("foo"), .subscribe("foo")] == self.subscriber.channelEdits)
    }

    @MainActor
    @Test
    func channelBindingNotSubscribed() {
        let channelNotFoo = self.state.makeBinding(channelListID: "not foo")
        #expect(!channelNotFoo.wrappedValue)

        channelNotFoo.wrappedValue.toggle()
        #expect(channelNotFoo.wrappedValue)
        #expect([.subscribe("not foo")] == self.subscriber.channelEdits)
    }

    @MainActor
    @Test
    func contactBinding() {
        let contactBaz = self.state.makeBinding(
            contactListID: "baz",
            scopes: [.app]
        )
        #expect(contactBaz.wrappedValue)

        contactBaz.wrappedValue.toggle()
        #expect(!contactBaz.wrappedValue)
        #expect([.unsubscribe("baz", .app)] == self.subscriber.contactEdits)

        contactBaz.wrappedValue.toggle()
        #expect([.unsubscribe("baz", .app), .subscribe("baz", .app)] == self.subscriber.contactEdits)
    }

    @MainActor
    @Test
    func contactlBindingNotSubscribed() {
        let contactNotBaz = self.state.makeBinding(
            contactListID: "not baz",
            scopes: [.app]
        )
        #expect(!contactNotBaz.wrappedValue)

        contactNotBaz.wrappedValue.toggle()
        #expect(contactNotBaz.wrappedValue)
        #expect([.subscribe("not baz", .app)] == self.subscriber.contactEdits)
    }

    @MainActor
    @Test
    func contactlBindingPartialScope() {
        let contactBaz = self.state.makeBinding(
            contactListID: "baz",
            scopes: [.app, .web]
        )
        #expect(contactBaz.wrappedValue)

        contactBaz.wrappedValue.toggle()
        #expect(!contactBaz.wrappedValue)
        #expect([.unsubscribe("baz", .app), .unsubscribe("baz", .web)] == self.subscriber.contactEdits)

        contactBaz.wrappedValue.toggle()
        #expect(
            [
                .unsubscribe("baz", .app),
                .unsubscribe("baz", .web),
                .subscribe("baz", .app),
                .subscribe("baz", .web)
            ] == self.subscriber.contactEdits)
    }

    @MainActor
    @Test
    func contactDifferentScope() {
        let contactBaz = self.state.makeBinding(
            contactListID: "baz",
            scopes: [.web]
        )
        #expect(!contactBaz.wrappedValue)
    }

    @MainActor
    @Test
    func channelMergeData() {
        let state = PreferenceCenterState(
            config: PreferenceCenterConfig(
                identifier: "empty",
                sections: [],
                options: PreferenceCenterConfig.Options(
                    mergeChannelDataToContact: true
                )
            ),
            contactSubscriptions: [
                "baz": [.web]
            ],
            channelSubscriptions: ["foo", "baz"],
            subscriber: subscriber
        )

        let contactAppBaz = state.makeBinding(
            contactListID: "baz",
            scopes: [.app]
        )
        #expect(contactAppBaz.wrappedValue)

        contactAppBaz.wrappedValue.toggle()
        #expect(contactAppBaz.wrappedValue)
        #expect([.unsubscribe("baz", .app)] == self.subscriber.contactEdits)
        #expect(self.subscriber.channelEdits.isEmpty)
    }

    @MainActor
    @Test
    func channelExternalUpdates() {
        let channelFoo = self.state.makeBinding(channelListID: "foo")
        #expect(channelFoo.wrappedValue)

        self.subscriber.channelEditsSubject.send(.subscribe("foo"))
        #expect(channelFoo.wrappedValue)

        self.subscriber.channelEditsSubject.send(.unsubscribe("foo"))
        #expect(!channelFoo.wrappedValue)

        self.subscriber.channelEditsSubject.send(.unsubscribe("foo"))
        #expect(!channelFoo.wrappedValue)

        self.subscriber.channelEditsSubject.send(.subscribe("foo"))
        #expect(channelFoo.wrappedValue)
    }

    @MainActor
    @Test
    func contactExternalUpdates() {
        let contactBaz = self.state.makeBinding(
            contactListID: "baz",
            scopes: [.app]
        )
        #expect(contactBaz.wrappedValue)

        self.subscriber.contactEditsSubject.send(.subscribe("baz", .app))
        #expect(contactBaz.wrappedValue)

        self.subscriber.contactEditsSubject.send(.unsubscribe("baz", .app))
        #expect(!contactBaz.wrappedValue)

        self.subscriber.contactEditsSubject.send(.unsubscribe("baz", .app))
        #expect(!contactBaz.wrappedValue)

        self.subscriber.contactEditsSubject.send(.subscribe("baz", .app))
        #expect(contactBaz.wrappedValue)
    }
}

class TestPreferenceSubscriber: PreferenceSubscriber {
    let channelEditsSubject = PassthroughSubject<SubscriptionListEdit, Never>()
    var channelSubscriptionListEdits: AnyPublisher<SubscriptionListEdit, Never>
    {
        return channelEditsSubject.eraseToAnyPublisher()
    }

    let contactEditsSubject = PassthroughSubject<
        ScopedSubscriptionListEdit, Never
    >()
    var contactSubscriptionListEdits:
        AnyPublisher<ScopedSubscriptionListEdit, Never>
    {
        return contactEditsSubject.eraseToAnyPublisher()
    }

    var channelEdits = [SubscriptionListEdit]()
    var contactEdits = [ScopedSubscriptionListEdit]()

    func updateChannelSubscription(_ listID: String, subscribe: Bool) {
        var edit: SubscriptionListEdit!
        if subscribe {
            edit = .subscribe(listID)
        } else {
            edit = .unsubscribe(listID)
        }
        self.channelEdits.append(edit)
        self.channelEditsSubject.send(edit)
    }

    func updateContactSubscription(
        _ listID: String,
        scopes: [ChannelScope],
        subscribe: Bool
    ) {
        scopes.forEach { scope in
            var edit: ScopedSubscriptionListEdit!
            if subscribe {
                edit = .subscribe(listID, scope)
            } else {
                edit = .unsubscribe(listID, scope)
            }
            self.contactEdits.append(edit)
            self.contactEditsSubject.send(edit)
        }
    }
}
