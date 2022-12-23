/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

final class FetchDeviceInfoActionTest: XCTestCase {

    private let channel = TestChannel()
    private let contact = TestContact()
    private let push = TestPush()

    var action: FetchDeviceInfoAction!

    override func setUp() async throws {
        action = FetchDeviceInfoAction(
            channel: { return self.channel },
            contact: { return self.contact },
            push: { return self.push }
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
            Situation.backgroundPush
        ]

        validSituations.forEach { (situation) in
            let args = ActionArguments(value: [[:]], with: situation)
            XCTAssertTrue(self.action.acceptsArguments(args))
        }
    }

    func testPerform() throws {
        self.channel.identifier = "some-channel-id"
        self.contact.namedUserID = "some-named-user"
        self.channel.tags = ["tag1", "tag2", "tag3"]
        self.push.isPushNotificationsOptedIn = true

        let expectation = self.expectation(description: "action ran")
        var actionResult: ActionResult!
        self.action.perform(
            with: ActionArguments(
                value: nil,
                with: .manualInvocation
            )
        ) { result in
            actionResult = result
            expectation.fulfill()
        }

        self.waitForExpectations(timeout: 10)

        let expectedResult = [
            "tags": ["tag1", "tag2", "tag3"],
            "push_opt_in": true,
            "named_user": "some-named-user",
            "channel_id": "some-channel-id"
        ] as NSDictionary

        XCTAssertEqual(actionResult.value as! NSDictionary, expectedResult)
    }
}
