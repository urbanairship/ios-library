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
            channel: { return self.channel },
            contact: { return self.contact }
        )
    }

    func testAcceptsArguments() throws {
        let validValue = [
            "channel": [
                "set": ["name": "clive"],
            ]
        ]

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
            let validArgs = ActionArguments(
                value: validValue,
                with: situation
            )
            XCTAssertTrue(self.action.acceptsArguments(validArgs))

            let invalidArgs = ActionArguments(
                value: nil,
                with: situation
            )
            XCTAssertFalse(self.action.acceptsArguments(invalidArgs))

        }

        rejectedSituations.forEach { (situation) in
            let args = ActionArguments(value: validValue, with: situation)
            XCTAssertFalse(self.action.acceptsArguments(args))
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


        let _ = await self.action.perform(
            with: ActionArguments(
                value: value,
                with: .manualInvocation
            )
        )

        await fulfillmentCompat(of: [attributesSet])

    }
}
