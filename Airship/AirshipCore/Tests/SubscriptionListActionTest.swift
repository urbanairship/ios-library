/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable import AirshipCore

@Suite struct SubscriptionListActionTests {

    private let channel = TestChannel()
    private let contact = TestContact()
    private let date = UATestDate(offset: 0, dateOverride: Date())
    private let action: SubscriptionListAction

    private let edits = SubscriptionListActionEdits()

    init() {
        let channel = self.channel
        let contact = self.contact
        let date = self.date
        let edits = self.edits

        self.action = SubscriptionListAction(
            channel: { channel },
            contact: { contact }
        )

        channel.subscriptionListEditor = SubscriptionListEditor { updates in
            edits.appendChannel(updates)
        }

        contact.subscriptionListEditor = ScopedSubscriptionListEditor(
            date: date
        ) { updates in
            edits.appendContact(updates)
        }
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
            let args = ActionArguments(situation: situation)
            let result = await self.action.accepts(arguments: args)
            #expect(result)
        }

        for situation in rejectedSituations {
            let args = ActionArguments(situation: situation)
            let result = await self.action.accepts(arguments: args)
            #expect(!(result))
        }
    }

    @Test
    func testPerformWithoutArgs() async throws {
        let args = ActionArguments()
        do {
            _ = try await action.perform(arguments: args)
            Issue.record("should throw")
        } catch {}
    }

    @Test
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
        #expect(expectedChannelEdits == self.edits.channelEdits)

        let expectedContactEdits = [
            ScopedSubscriptionListUpdate(
                listId: "4567",
                type: .unsubscribe,
                scope: .app,
                date: self.date.now
            )
        ]
        #expect(expectedContactEdits == self.edits.contactEdits)
    }

    @Test
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
        #expect(expectedChannelEdits == self.edits.channelEdits)

        let expectedContactEdits = [
            ScopedSubscriptionListUpdate(
                listId: "4567",
                type: .unsubscribe,
                scope: .app,
                date: self.date.now
            )
        ]
        #expect(expectedContactEdits == self.edits.contactEdits)
    }

    @Test
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
            Issue.record("should throw")
        } catch {}

        #expect(self.edits.channelEdits.isEmpty)
        #expect(self.edits.contactEdits.isEmpty)
    }

}

fileprivate final class SubscriptionListActionEdits: @unchecked Sendable {
    private let lock = NSLock()
    private var _channelEdits: [SubscriptionListUpdate] = []
    private var _contactEdits: [ScopedSubscriptionListUpdate] = []

    var channelEdits: [SubscriptionListUpdate] {
        lock.withLock { _channelEdits }
    }

    var contactEdits: [ScopedSubscriptionListUpdate] {
        lock.withLock { _contactEdits }
    }

    func appendChannel(_ updates: [SubscriptionListUpdate]) {
        lock.withLock { _channelEdits.append(contentsOf: updates) }
    }

    func appendContact(_ updates: [ScopedSubscriptionListUpdate]) {
        lock.withLock { _contactEdits.append(contentsOf: updates) }
    }
}
