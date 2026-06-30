/* Copyright Airship and Contributors */

import Testing

@testable import AirshipCore
import Foundation

@Suite struct AudienceUtilsTest {

    @Test
    func testCollapseTagGroupUpdates() throws {
        let updates = [
            TagGroupUpdate(
                group: "some-group",
                tags: ["1", "2", "3"],
                type: .remove
            ),
            TagGroupUpdate(group: "some-group", tags: ["1", "2"], type: .add),
            TagGroupUpdate(group: "some-group", tags: ["4"], type: .set),
            TagGroupUpdate(group: "some-group", tags: ["5", "6"], type: .add),
            TagGroupUpdate(group: "some-group", tags: ["5"], type: .remove),
            TagGroupUpdate(
                group: "some-other-group",
                tags: ["10", "11"],
                type: .remove
            ),
            TagGroupUpdate(group: "some-other-group", tags: ["12"], type: .add),
            TagGroupUpdate(group: "some-other-group", tags: ["10"], type: .add),
        ]

        let collapsed = AudienceUtils.collapse(updates)

        #expect(3 == collapsed.count)
        #expect("some-group" == collapsed[0].group)
        #expect(Set(["6", "4"]) == Set(collapsed[0].tags))
        #expect(.set == collapsed[0].type)

        #expect("some-other-group" == collapsed[1].group)
        #expect(Set(["12", "10"]) == Set(collapsed[1].tags))
        #expect(.add == collapsed[1].type)

        #expect("some-other-group" == collapsed[2].group)
        #expect(Set(["11"]) == Set(collapsed[2].tags))
        #expect(.remove == collapsed[2].type)
    }

    @Test
    func testCollapseTagGroupUpdatesEmptyTags() throws {
        let updates = [
            TagGroupUpdate(group: "set-group", tags: [], type: .set),
            TagGroupUpdate(group: "add-group", tags: [], type: .add),
            TagGroupUpdate(group: "remove-group", tags: [], type: .remove),

        ]

        let collapsed = AudienceUtils.collapse(updates)

        #expect(1 == collapsed.count)
        #expect("set-group" == collapsed[0].group)
        #expect(Set([]) == Set(collapsed[0].tags))
        #expect(.set == collapsed[0].type)
    }

    @Test
    func testCollapseAttributeUpdates() throws {
        let date = Date()
        let updates = [
            AttributeUpdate.remove(attribute: "some-attribute", date: date),
            AttributeUpdate.set(
                attribute: "some-attribute",
                value: "neat",
                date: date
            ),
            AttributeUpdate.set(
                attribute: "some-other-attribute",
                value: 12,
                date: date
            ),
            AttributeUpdate.remove(
                attribute: "some-other-attribute",
                date: date
            ),
        ]

        let collapsed = AudienceUtils.collapse(updates)

        #expect(2 == collapsed.count)
        #expect("some-attribute" == collapsed[0].attribute)
        #expect((collapsed[0].jsonValue?.unWrap() as! String) == "neat")
        #expect(.set == collapsed[0].type)
        #expect(date == collapsed[0].date)

        #expect("some-other-attribute" == collapsed[1].attribute)
        #expect(collapsed[1].jsonValue?.unWrap() == nil)
        #expect(.remove == collapsed[1].type)
        #expect(.set == collapsed[0].type)
    }

    @Test
    func testCollapseSubscriptionListUpdates() throws {
        let updates = [
            SubscriptionListUpdate(listId: "coffee", type: .unsubscribe),
            SubscriptionListUpdate(listId: "pizza", type: .subscribe),
            SubscriptionListUpdate(listId: "coffee", type: .subscribe),
            SubscriptionListUpdate(listId: "pizza", type: .unsubscribe),
        ]

        let expected = [
            SubscriptionListUpdate(listId: "coffee", type: .subscribe),
            SubscriptionListUpdate(listId: "pizza", type: .unsubscribe),
        ]

        let collapsed = AudienceUtils.collapse(updates)

        #expect(expected == collapsed)
    }

    @Test
    func testCollapseScopedSubscriptionListUpdates() throws {
        let now = Date()

        let updates = [
            ScopedSubscriptionListUpdate(
                listId: "foo",
                type: .subscribe,
                scope: .sms,
                date: now.advanced(by: 1)
            ),
            ScopedSubscriptionListUpdate(
                listId: "foo",
                type: .subscribe,
                scope: .app,
                date: now.advanced(by: 2)
            ),
            ScopedSubscriptionListUpdate(
                listId: "bar",
                type: .subscribe,
                scope: .web,
                date: now.advanced(by: 3)
            ),
            ScopedSubscriptionListUpdate(
                listId: "foo",
                type: .subscribe,
                scope: .sms,
                date: now.advanced(by: 4)
            ),
            ScopedSubscriptionListUpdate(
                listId: "foo",
                type: .subscribe,
                scope: .app,
                date: now.advanced(by: 5)
            ),

            ScopedSubscriptionListUpdate(
                listId: "bar",
                type: .subscribe,
                scope: .app,
                date: now.advanced(by: 6)
            ),

            ScopedSubscriptionListUpdate(
                listId: "bar",
                type: .unsubscribe,
                scope: .app,
                date: now.advanced(by: 7)
            ),
        ]

        let expected = [
            ScopedSubscriptionListUpdate(
                listId: "bar",
                type: .subscribe,
                scope: .web,
                date: now.advanced(by: 3)
            ),
            ScopedSubscriptionListUpdate(
                listId: "foo",
                type: .subscribe,
                scope: .sms,
                date: now.advanced(by: 4)
            ),
            ScopedSubscriptionListUpdate(
                listId: "foo",
                type: .subscribe,
                scope: .app,
                date: now.advanced(by: 5)
            ),
            ScopedSubscriptionListUpdate(
                listId: "bar",
                type: .unsubscribe,
                scope: .app,
                date: now.advanced(by: 7)
            ),
        ]

        let collapsed = AudienceUtils.collapse(updates)

        #expect(expected == collapsed)
    }

    @Test
    func testApplyScopedSubscriptionListsEmptyPayload() throws {
        let now = Date()

        let updates = [
            ScopedSubscriptionListUpdate(
                listId: "bar",
                type: .subscribe,
                scope: .web,
                date: now.advanced(by: 3)
            ),
            ScopedSubscriptionListUpdate(
                listId: "foo",
                type: .subscribe,
                scope: .sms,
                date: now.advanced(by: 4)
            ),
            ScopedSubscriptionListUpdate(
                listId: "foo",
                type: .subscribe,
                scope: .app,
                date: now.advanced(by: 5)
            ),
            ScopedSubscriptionListUpdate(
                listId: "bar",
                type: .unsubscribe,
                scope: .app,
                date: now.advanced(by: 7)
            ),
        ]

        let expected: [String: [ChannelScope]] = [
            "foo": [.sms, .app],
            "bar": [.web],
        ]

        #expect(
            expected ==
            AudienceUtils.applySubscriptionListsUpdates(nil, updates: updates)
        )
        #expect(
            expected ==
            AudienceUtils.applySubscriptionListsUpdates([:], updates: updates)
        )
    }

    @Test
    func testApplyScopedSubscriptionLists() throws {
        let now = Date()

        let updates = [
            ScopedSubscriptionListUpdate(
                listId: "bar",
                type: .subscribe,
                scope: .web,
                date: now.advanced(by: 3)
            ),
            ScopedSubscriptionListUpdate(
                listId: "foo",
                type: .subscribe,
                scope: .sms,
                date: now.advanced(by: 4)
            ),
            ScopedSubscriptionListUpdate(
                listId: "foo",
                type: .subscribe,
                scope: .app,
                date: now.advanced(by: 5)
            ),
            ScopedSubscriptionListUpdate(
                listId: "bar",
                type: .unsubscribe,
                scope: .app,
                date: now.advanced(by: 7)
            ),
        ]

        let expected: [String: [ChannelScope]] = [
            "baz": [.email],
            "foo": [.app, .web, .sms],
            "bar": [.web],
        ]

        let payload: [String: [ChannelScope]] = [
            "baz": [.email],
            "bar": [.app],
            "foo": [.app, .web],
        ]

        #expect(
            expected ==
            AudienceUtils.applySubscriptionListsUpdates(
                payload,
                updates: updates
            )
        )
    }
}
