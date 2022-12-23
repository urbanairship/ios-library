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
            channel: { return self.channel },
            contact: { return self.contact }
        )
    }

    func testAcceptsArguments() throws {
        let validSituations = [
            Situation.foregroundInteractiveButton,
            Situation.launchedFromPush,
            Situation.manualInvocation,
            Situation.webViewInvocation,
            Situation.automation,
            Situation.foregroundPush,
            Situation.backgroundInteractiveButton,
        ]

        let rejectedSituations = [
            Situation.backgroundPush
        ]

        validSituations.forEach { (situation) in
            XCTAssertTrue(
                self.action.acceptsArguments(
                    ActionArguments(
                        value: simpleValue,
                        with: situation
                    )
                )
            )

            XCTAssertTrue(
                self.action.acceptsArguments(
                    ActionArguments(
                        value: complexValue,
                        with: situation
                    )
                )
            )

            XCTAssertFalse(
                self.action.acceptsArguments(
                    ActionArguments(
                        value: nil,
                        with: situation
                    )
                )
            )
        }

        rejectedSituations.forEach { (situation) in
            XCTAssertFalse(
                self.action.acceptsArguments(
                    ActionArguments(
                        value: simpleValue,
                        with: situation
                    )
                )
            )

            XCTAssertFalse(
                self.action.acceptsArguments(
                    ActionArguments(
                        value: complexValue,
                        with: situation
                    )
                )
            )
        }
    }

    func testPerformSimple() throws {
        self.channel.tags = ["foo", "bar"]

        let actionExpectation = self.expectation(description: "action")
        self.action.perform(
            with: ActionArguments(
                value: simpleValue,
                with: .manualInvocation
            )
        ) { result in
            actionExpectation.fulfill()
        }

        self.waitForExpectations(timeout: 10)

        XCTAssertEqual(
            ["foo", "bar", "tag", "another tag"],
            channel.tags
        )
    }

    func testPerformComplex() throws {
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

        let actionExpectation = self.expectation(description: "action")
        self.action.perform(
            with: ActionArguments(
                value: complexValue,
                with: .manualInvocation
            )
        ) { result in
            actionExpectation.fulfill()
        }

        self.waitForExpectations(timeout: 10)

        XCTAssertEqual(
            ["foo", "bar", "tag", "another_tag"],
            channel.tags
        )
    }
}


