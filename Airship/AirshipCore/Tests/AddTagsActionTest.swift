/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

final class AddTagsActionTest: XCTestCase {

    private let simpleValue = ["tag", "another tag"]
    private let complexValue: [String: AnyHashable] = [
        "channel": [
            "channel_tag_group": ["channel_tag_1", "channel_tag_2"],
            "other_channel_tag_group": ["other_channel_tag_1"]
        ],
        "named_user": [
            "named_user_tag_group": ["named_user_tag_1", "named_user_tag_2"],
            "other_named_user_tag_group": ["other_named_user_tag_1"]
        ],
        "device": [ "tag", "another_tag"]
    ]

    private let channel = TestChannel()
    private let contact = TestContact()
    private var action: AddTagsAction!

    override func setUp() async throws {
        action = AddTagsAction(
            channel: { [channel] in return channel },
            contact: { [contact] in return contact }
        )
    }

    func testAcceptsArguments() async throws {
        let validSituations = [
            ActionSituation.foregroundInteractiveButton,
            ActionSituation.launchedFromPush,
            ActionSituation.manualInvocation,
            ActionSituation.webViewInvocation,
            ActionSituation.automation,
            ActionSituation.foregroundPush,
            ActionSituation.backgroundInteractiveButton,
        ]

        let rejectedSituations = [
            ActionSituation.backgroundPush
        ]

        for situation in validSituations {
            let args = ActionArguments(value: try! AirshipJSON.wrap(simpleValue), situation: situation)
            let result = await self.action.accepts(arguments: args)
            XCTAssertTrue(result)
        }

        for situation in validSituations {
            let args = ActionArguments(value: try! AirshipJSON.wrap(complexValue), situation: situation)
            let result = await self.action.accepts(arguments: args)
            XCTAssertTrue(result)
        }

        for situation in rejectedSituations {
            let args = ActionArguments(value: try! AirshipJSON.wrap(simpleValue), situation: situation)
            let result = await self.action.accepts(arguments: args)
            XCTAssertFalse(result)
        }
    }

    func testPerformSimple() async throws {
        self.channel.tags = ["foo", "bar"]
        
        let updates = await self.action.tagMutations

        _ = try await self.action.perform(arguments:
            ActionArguments(
                value: try! AirshipJSON.wrap(simpleValue),
                situation: .manualInvocation
            )
        )
        
        var iterator = updates.makeAsyncIterator()
        let tagsAction = await iterator.next()
        XCTAssertEqual(TagActionMutation.channelTags(simpleValue), tagsAction)

        XCTAssertEqual(
            ["foo", "bar", "tag", "another tag"],
            channel.tags
        )
    }

    func testPerformComplex() async throws {
        self.channel.tags = ["foo", "bar"]

        let tagGroupsSet = self.expectation(description: "tagGroupsSet")
        tagGroupsSet.expectedFulfillmentCount = 2

        self.channel.tagGroupEditor = TagGroupsEditor { updates in
            let expected = [
                TagGroupUpdate(
                    group: "channel_tag_group",
                    tags: ["channel_tag_1", "channel_tag_2"],
                    type: .add
                ),
                TagGroupUpdate(
                    group: "other_channel_tag_group",
                    tags: ["other_channel_tag_1"],
                    type: .add
                )
            ]

            XCTAssertEqual(Set(expected), Set(updates))
            tagGroupsSet.fulfill()
        }

        self.contact.tagGroupEditor = TagGroupsEditor { updates in
            let expected = [
                TagGroupUpdate(
                    group: "named_user_tag_group",
                    tags: ["named_user_tag_1", "named_user_tag_2"],
                    type: .add
                ),
                TagGroupUpdate(
                    group: "other_named_user_tag_group",
                    tags: ["other_named_user_tag_1"],
                    type: .add
                )
            ]

            XCTAssertEqual(Set(expected), Set(updates))
            tagGroupsSet.fulfill()
        }
        
        let updates = await self.action.tagMutations

        _ = try await self.action.perform(arguments:
            ActionArguments(
                value: try! AirshipJSON.wrap(complexValue),
                situation: .manualInvocation
            )
        )
        
        var expectedActions: [TagActionMutation] = [
            .channelTagGroups(["channel_tag_group": ["channel_tag_1", "channel_tag_2"], "other_channel_tag_group": ["other_channel_tag_1"]]),
            .contactTagGroups(["named_user_tag_group": ["named_user_tag_1", "named_user_tag_2"], "other_named_user_tag_group": ["other_named_user_tag_1"]]),
            .channelTags(["tag", "another_tag"]),
        ]
        
        for await item in updates {
            XCTAssertEqual(item, expectedActions.removeFirst())
            if (expectedActions.isEmpty) {
                break
            }
        }

        XCTAssertEqual(
            ["foo", "bar", "tag", "another_tag"],
            channel.tags
        )
        await fulfillment(of: [tagGroupsSet])
    }
}


