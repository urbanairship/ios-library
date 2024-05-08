/* Copyright Airship and Contributors */

import AirshipCore
import Combine
import XCTest

@testable import AirshipPreferenceCenter

class PreferenceCenterStateTest: XCTestCase {
    let subscriber = TestPreferenceSubscriber()
    var state: PreferenceCenterState!

    override func setUp() {
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

    func testChannelBinding() {
        let channelFoo = self.state.makeBinding(channelListID: "foo")
        XCTAssertTrue(channelFoo.wrappedValue)

        channelFoo.wrappedValue.toggle()
        XCTAssertFalse(channelFoo.wrappedValue)
        XCTAssertEqual([.unsubscribe("foo")], self.subscriber.channelEdits)

        channelFoo.wrappedValue.toggle()
        XCTAssertEqual(
            [.unsubscribe("foo"), .subscribe("foo")],
            self.subscriber.channelEdits
        )
    }

    func testChannelBindingNotSubscribed() {
        let channelNotFoo = self.state.makeBinding(channelListID: "not foo")
        XCTAssertFalse(channelNotFoo.wrappedValue)

        channelNotFoo.wrappedValue.toggle()
        XCTAssertTrue(channelNotFoo.wrappedValue)
        XCTAssertEqual([.subscribe("not foo")], self.subscriber.channelEdits)
    }

    func testContactBinding() {
        let contactBaz = self.state.makeBinding(
            contactListID: "baz",
            scopes: [.app]
        )
        XCTAssertTrue(contactBaz.wrappedValue)

        contactBaz.wrappedValue.toggle()
        XCTAssertFalse(contactBaz.wrappedValue)
        XCTAssertEqual(
            [.unsubscribe("baz", .app)],
            self.subscriber.contactEdits
        )

        contactBaz.wrappedValue.toggle()
        XCTAssertEqual(
            [.unsubscribe("baz", .app), .subscribe("baz", .app)],
            self.subscriber.contactEdits
        )
    }

    func testContactlBindingNotSubscribed() {
        let contactNotBaz = self.state.makeBinding(
            contactListID: "not baz",
            scopes: [.app]
        )
        XCTAssertFalse(contactNotBaz.wrappedValue)

        contactNotBaz.wrappedValue.toggle()
        XCTAssertTrue(contactNotBaz.wrappedValue)
        XCTAssertEqual(
            [.subscribe("not baz", .app)],
            self.subscriber.contactEdits
        )
    }

    func testContactlBindingPartialScope() {
        let contactBaz = self.state.makeBinding(
            contactListID: "baz",
            scopes: [.app, .web]
        )
        XCTAssertTrue(contactBaz.wrappedValue)

        contactBaz.wrappedValue.toggle()
        XCTAssertFalse(contactBaz.wrappedValue)
        XCTAssertEqual(
            [.unsubscribe("baz", .app), .unsubscribe("baz", .web)],
            self.subscriber.contactEdits
        )

        contactBaz.wrappedValue.toggle()
        XCTAssertEqual(
            [
                .unsubscribe("baz", .app),
                .unsubscribe("baz", .web),
                .subscribe("baz", .app),
                .subscribe("baz", .web),
            ],
            self.subscriber.contactEdits
        )
    }

    func testContactDifferentScope() {
        let contactBaz = self.state.makeBinding(
            contactListID: "baz",
            scopes: [.web]
        )
        XCTAssertFalse(contactBaz.wrappedValue)
    }

    func testChannelMergeData() {
        state = PreferenceCenterState(
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

        let contactAppBaz = self.state.makeBinding(
            contactListID: "baz",
            scopes: [.app]
        )
        XCTAssertTrue(contactAppBaz.wrappedValue)

        contactAppBaz.wrappedValue.toggle()
        XCTAssertTrue(contactAppBaz.wrappedValue)
        XCTAssertEqual(
            [.unsubscribe("baz", .app)],
            self.subscriber.contactEdits
        )
        XCTAssertEqual([], self.subscriber.channelEdits)
    }

    func testChannelExternalUpdates() {
        let channelFoo = self.state.makeBinding(channelListID: "foo")
        XCTAssertTrue(channelFoo.wrappedValue)

        self.subscriber.channelEditsSubject.send(.subscribe("foo"))
        XCTAssertTrue(channelFoo.wrappedValue)

        self.subscriber.channelEditsSubject.send(.unsubscribe("foo"))
        XCTAssertFalse(channelFoo.wrappedValue)

        self.subscriber.channelEditsSubject.send(.unsubscribe("foo"))
        XCTAssertFalse(channelFoo.wrappedValue)

        self.subscriber.channelEditsSubject.send(.subscribe("foo"))
        XCTAssertTrue(channelFoo.wrappedValue)
    }

    func testContactExternalUpdates() {
        let contactBaz = self.state.makeBinding(
            contactListID: "baz",
            scopes: [.app]
        )
        XCTAssertTrue(contactBaz.wrappedValue)

        self.subscriber.contactEditsSubject.send(.subscribe("baz", .app))
        XCTAssertTrue(contactBaz.wrappedValue)

        self.subscriber.contactEditsSubject.send(.unsubscribe("baz", .app))
        XCTAssertFalse(contactBaz.wrappedValue)

        self.subscriber.contactEditsSubject.send(.unsubscribe("baz", .app))
        XCTAssertFalse(contactBaz.wrappedValue)

        self.subscriber.contactEditsSubject.send(.subscribe("baz", .app))
        XCTAssertTrue(contactBaz.wrappedValue)
    }
}

class TestPreferenceSubscriber: PreferenceSubscriber {
    let channelEditsSubject = PassthroughSubject<SubscriptionListEdit, Never>()
    var channelSubscriptionListEdits: AnyPublisher<SubscriptionListEdit, Never>
    {
        return channelEditsSubject.eraseToAnyPublisher()
    }
    
    private let channelAssociationSubject = PassthroughSubject<[AssociatedChannel], Never>()
    var channelAssociationPublisher: AnyPublisher<[AssociatedChannel], Never>
    {
        return channelAssociationSubject.eraseToAnyPublisher()
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
