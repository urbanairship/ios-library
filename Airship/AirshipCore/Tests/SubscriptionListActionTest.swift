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
            channel: { [channel] in return channel },
            contact: { [contact] in return contact }
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
            let args = ActionArguments(situation: situation)
            let result = await self.action.accepts(arguments: args)
            XCTAssertTrue(result)
        }

        for situation in rejectedSituations {
            let args = ActionArguments(situation: situation)
            let result = await self.action.accepts(arguments: args)
            XCTAssertFalse(result)
        }
    }

    func testPerformWithoutArgs() async throws {
        let args = ActionArguments()
        do {
            _ = try await action.perform(arguments: args)
            XCTFail("should throw")
        } catch {}
    }

    func testPerformWithValidPayload() async throws {
        let actionValue: [[String: String]] = [
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

        let args = ActionArguments(
            value: try AirshipJSON.wrap(actionValue)
        )
    
        _ = try await action.perform(arguments: args)

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

    func testPerformWithAltValidPayload() async throws {
        let actionValue: [String: Any] = [
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


        let args = ActionArguments(
            value: try AirshipJSON.wrap(actionValue)
        )

        _ = try await action.perform(arguments: args)

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

    func testPerformWithInvalidPayload() async throws {
        let actionValue: [String: Any] = [
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


        let args = ActionArguments(
            value: try AirshipJSON.wrap(actionValue)
        )


        do {
            _ = try await action.perform(arguments: args)
            XCTFail("should throw")
        } catch {}

        XCTAssertTrue(self.channelEdits.isEmpty)
        XCTAssertTrue(self.contactEdits.isEmpty)
    }

}
