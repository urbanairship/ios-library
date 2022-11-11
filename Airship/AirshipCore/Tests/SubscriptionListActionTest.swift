/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore

class SubscriptionListActionTests: XCTestCase {

    private let channel = TestChannel()
    private let contact = TestContact()
    private let date = UATestDate(offset: 0, dateOverride: Date())
    private var action: SubscriptionListAction!

    private var channelEdits: [SubscriptionListUpdate] = []
    private var contactEdits: [ScopedSubscriptionListUpdate] = []

    override func setUp() {
        self.action = SubscriptionListAction(
            channel: { return self.channel },
            contact: { return self.contact }
        )

        self.channel.subscriptionListEditor = SubscriptionListEditor {
            updates in
            self.channelEdits.append(contentsOf: updates)
        }

        self.contact.subscriptionListEditor = ScopedSubscriptionListEditor(
            date: date
        ) { updates in
            self.contactEdits.append(contentsOf: updates)
        }
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
            let args = ActionArguments(value: [[:]], with: situation)
            XCTAssertTrue(self.action.acceptsArguments(args))
        }

        rejectedSituations.forEach { (situation) in
            let args = ActionArguments(value: [[:]], with: situation)
            XCTAssertFalse(self.action.acceptsArguments(args))
        }
    }

    func testPerformWithoutArgs() throws {
        let expectation = XCTestExpectation(description: "Completed")
        let args = ActionArguments(value: nil, with: .manualInvocation)
        action.perform(with: args) { (result) in
            XCTAssertNil(result.value)
            XCTAssertNotNil(result.error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)

        XCTAssertTrue(self.channelEdits.isEmpty)
        XCTAssertTrue(self.contactEdits.isEmpty)
    }

    func testPerformWithValidPayload() throws {
        let actionValue = [
            [
                "type": "channel",
                "action": "subscribe",
                "list": "456",
            ],
            [
                "type": "contact",
                "action": "unsubscribe",
                "list": "4567",
                "scope": "app",
            ],
        ]

        let args = ActionArguments(value: actionValue, with: .manualInvocation)
        let expectation = XCTestExpectation(description: "Completed")
        action.perform(with: args) { (result) in
            XCTAssertNil(result.value)
            XCTAssertNil(result.error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)

        let expectedChannelEdits = [
            SubscriptionListUpdate(listId: "456", type: .subscribe)
        ]
        XCTAssertEqual(expectedChannelEdits, self.channelEdits)

        let expectedContactEdits = [
            ScopedSubscriptionListUpdate(
                listId: "4567",
                type: .unsubscribe,
                scope: .app,
                date: self.date.now
            )
        ]
        XCTAssertEqual(expectedContactEdits, self.contactEdits)
    }

    func testPerformWithAltValidPayload() throws {
        let actionValue = [
            "edits": [
                [
                    "type": "channel",
                    "action": "subscribe",
                    "list": "456",
                ],
                [
                    "type": "contact",
                    "action": "unsubscribe",
                    "list": "4567",
                    "scope": "app",
                ],
            ]
        ]

        let args = ActionArguments(value: actionValue, with: .manualInvocation)
        let expectation = XCTestExpectation(description: "Completed")
        action.perform(with: args) { (result) in
            XCTAssertNil(result.value)
            XCTAssertNil(result.error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)

        let expectedChannelEdits = [
            SubscriptionListUpdate(listId: "456", type: .subscribe)
        ]
        XCTAssertEqual(expectedChannelEdits, self.channelEdits)

        let expectedContactEdits = [
            ScopedSubscriptionListUpdate(
                listId: "4567",
                type: .unsubscribe,
                scope: .app,
                date: self.date.now
            )
        ]
        XCTAssertEqual(expectedContactEdits, self.contactEdits)
    }

    func testPerformWithInvalidPayload() throws {
        let actionValue = [
            "edits": [
                [
                    "type": "channel",
                    "action": "subscribe",
                    "list": "456",
                ],
                [
                    "type": "contact",
                    "list": "4567",
                    "scope": "app",
                ],
            ]
        ]

        let args = ActionArguments(value: actionValue, with: .manualInvocation)
        let expectation = XCTestExpectation(description: "Completed")
        action.perform(with: args) { (result) in
            XCTAssertNil(result.value)
            XCTAssertNotNil(result.error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)

        XCTAssertTrue(self.channelEdits.isEmpty)
        XCTAssertTrue(self.contactEdits.isEmpty)
    }

}
