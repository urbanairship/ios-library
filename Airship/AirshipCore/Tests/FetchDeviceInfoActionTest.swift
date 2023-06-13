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
            channel: { [channel] in return channel },
            contact: { [contact] in return contact },
            push: { [push] in return push }
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
            ActionSituation.backgroundPush
        ]

        for situation in validSituations {
            let args = ActionArguments(value: AirshipJSON.null, situation: situation)
            let result = await self.action.accepts(arguments: args)
            XCTAssertTrue(result)
        }
    }

    @MainActor
    func testPerform() async throws {
        self.channel.identifier = "some-channel-id"
        self.contact.namedUserID = "some-named-user"
        self.channel.tags = ["tag1", "tag2", "tag3"]
        self.push.isPushNotificationsOptedIn = true

        let actionResult = try await self.action.perform(
            arguments: ActionArguments(
                value: AirshipJSON.null,
                situation: .manualInvocation
            )
        )

        let expectedResult = try! AirshipJSON.wrap([
            "tags": ["tag1", "tag2", "tag3"],
            "push_opt_in": true,
            "named_user": "some-named-user",
            "channel_id": "some-channel-id"
        ] as [String : Any])

        XCTAssertEqual(actionResult, expectedResult)
    }
 
}
