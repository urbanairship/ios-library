/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

final class ModifyAttributesActionTest: XCTestCase {

    private let channel = TestChannel()
    private let contact = TestContact()
    private let push = TestPush()
    private let date = UATestDate()
    private var action: ModifyAttributesAction!

    override func setUp() async throws {
        date.dateOverride = Date()
        action = ModifyAttributesAction(
            channel: { [channel] in return channel },
            contact: { [contact] in return contact }
        )
    }

    func testAcceptsArguments() async throws {
        let validValue = [
            "channel": [
                "set": ["name": "clive"],
            ]
        ]

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
            let args = ActionArguments(value: try AirshipJSON.wrap(validValue), situation: situation)
            let result = await self.action.accepts(arguments: args)
            XCTAssertTrue(result)
        }

        for situation in validSituations {
            let args = ActionArguments(situation: situation)
            let result = await self.action.accepts(arguments: args)
            XCTAssertFalse(result)
        }

        for situation in rejectedSituations {
            let args = ActionArguments(value: try AirshipJSON.wrap(validValue), situation: situation)
            let result = await self.action.accepts(arguments: args)
            XCTAssertFalse(result)
        }
    }

    func testPerform() async throws {
        let value: [String: Any] = [
            "channel": [
                "set": ["name": "clive"],
                "remove": ["zipcode"]
            ] as [String : Any],
            "named_user": [
                "set": ["some other name": "owen"],
                "remove": ["location"]
            ] as [String : Any]
        ]

        let expectedChannelAttributes = [
            AttributeUpdate(
                attribute: "zipcode",
                type: .remove,
                jsonValue: nil,
                date: self.date.now
            ),
            AttributeUpdate(
                attribute: "name",
                type: .set,
                jsonValue: .string("clive"),
                date: self.date.now
            )
        ]

        let expectedContactAttributes = [
            AttributeUpdate(
                attribute: "location",
                type: .remove,
                jsonValue: nil,
                date: self.date.now
            ),
            AttributeUpdate(
                attribute: "some other name",
                type: .set,
                jsonValue: .string("owen"),
                date: self.date.now
            )
        ]

        let attributesSet = self.expectation(description: "attributes")
        attributesSet.expectedFulfillmentCount = 2

        self.channel.attributeEditor = AttributesEditor(
            date: self.date
        ) { attributes in
            XCTAssertEqual(expectedChannelAttributes, attributes)
            attributesSet.fulfill()
        }


        self.contact.attributeEditor = AttributesEditor(
            date: self.date
        ) { attributes in
            XCTAssertEqual(expectedContactAttributes, attributes)
            attributesSet.fulfill()
        }


        let _ = try await self.action.perform(arguments:
            ActionArguments(
                value: try AirshipJSON.wrap(value),
                situation: .manualInvocation
            )
        )

        await fulfillment(of: [attributesSet])

    }
}
