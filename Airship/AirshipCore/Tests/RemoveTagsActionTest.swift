/* Copyright Airship and Contributors */

import Testing

@testable
import AirshipCore

@Suite(.timeLimit(.minutes(1)))
struct RemoveTagsActionTest {

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
    private let action: RemoveTagsAction

    init() async throws {
        let channel = self.channel
        let contact = self.contact
        action = RemoveTagsAction(
            channel: { channel },
            contact: { contact }
        )
    }

    @Test
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
            #expect(result)
        }

        for situation in validSituations {
            let args = ActionArguments(value: try! AirshipJSON.wrap(complexValue), situation: situation)
            let result = await self.action.accepts(arguments: args)
            #expect(result)
        }

        for situation in rejectedSituations {
            let args = ActionArguments(value: try! AirshipJSON.wrap(simpleValue), situation: situation)
            let result = await self.action.accepts(arguments: args)
            #expect(!(result))
        }
    }

    @Test
    func testPerformSimple() async throws {
        self.channel.tags = ["foo", "bar", "tag", "another tag"]
        
        let updates = await self.action.tagMutations

        _ = try await self.action.perform(arguments:
            ActionArguments(
                value: try! AirshipJSON.wrap(simpleValue),
                situation: .manualInvocation
            )
        )
        #expect(
            ["foo", "bar"] == channel.tags
        )
        
        var iterator = updates.makeAsyncIterator()
        let mutation = await iterator.next()
        #expect(TagActionMutation.channelTags(["tag", "another tag"]) == mutation)
    }

    @Test
    func testPerformComplex() async throws {
        self.channel.tags = ["foo", "bar", "tag"]

        let tagGroupsSet = AirshipTestExpectation(description: "tagGroupsSet")
        tagGroupsSet.expectedFulfillmentCount = 2

        self.channel.tagGroupEditor = TagGroupsEditor { updates in
            let expected = [
                TagGroupUpdate(
                    group: "channel_tag_group",
                    tags: ["channel_tag_1", "channel_tag_2"],
                    type: .remove
                ),
                TagGroupUpdate(
                    group: "other_channel_tag_group",
                    tags: ["other_channel_tag_1"],
                    type: .remove
                )
            ]

            #expect(Set(expected) == Set(updates))
            tagGroupsSet.fulfill()
        }

        self.contact.tagGroupEditor = TagGroupsEditor { updates in
            let expected = [
                TagGroupUpdate(
                    group: "named_user_tag_group",
                    tags: ["named_user_tag_1", "named_user_tag_2"],
                    type: .remove
                ),
                TagGroupUpdate(
                    group: "other_named_user_tag_group",
                    tags: ["other_named_user_tag_1"],
                    type: .remove
                )
            ]

            #expect(Set(expected) == Set(updates))
            tagGroupsSet.fulfill()
        }
        
        let updates = await self.action.tagMutations

        _ = try await self.action.perform(arguments:
            ActionArguments(
                value: try! AirshipJSON.wrap(complexValue),
                situation: .manualInvocation
            )
        )
        
        var expected: [TagActionMutation] = [
            .channelTagGroups(["channel_tag_group": ["channel_tag_1", "channel_tag_2"], "other_channel_tag_group": ["other_channel_tag_1"]]),
            .contactTagGroups(["named_user_tag_group": ["named_user_tag_1", "named_user_tag_2"], "other_named_user_tag_group": ["other_named_user_tag_1"]]),
            .channelTags(["tag", "another_tag"])
        ]
        
        for await item in updates {
            #expect(expected.removeFirst() == item)
            if expected.isEmpty {
                break
            }
        }
        

        #expect(
            ["foo", "bar"] == channel.tags
        )
        
        await fulfillment(of: [tagGroupsSet], timeout: 10)
    }
}
