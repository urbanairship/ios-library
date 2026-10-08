/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable @_spi(AirshipInternal)
import AirshipAutomation
import AirshipCore

struct AutomationScheduleTests {

    @Test
    func testParseActions() throws {
        let jsonString = """
           {
               "id": "test_schedule",
               "triggers": [
                   {
                       "type": "custom_event_count",
                       "goal": 1,
                       "id": "json-id"
                   }
               ],
               "group": "test_group",
               "priority": 2,
               "limit": 5,
               "start": "2023-12-20T00:00:00Z",
               "end": "2023-12-21T00:00:00Z",
               "audience": {},
               "delay": {},
               "interval": 3600,
               "type": "actions",
               "actions": {
                   "foo": "bar",
               },
               "bypass_holdout_groups": true,
               "edit_grace_period": 7,
               "metadata": {},
               "frequency_constraint_ids": ["constraint1", "constraint2"],
               "message_type": "test_type",
               "last_updated": "2023-12-20T12:30:00Z",
               "created": "2023-12-20T12:00:00Z",
               "additional_audience_check_overrides": {
                   "bypass": true,
                   "context": "json-context",
                   "url": "https://result.url"
               }
           }
           """

        let expectedSchedule = AutomationSchedule(
            identifier: "test_schedule",
            data: .actions(try AirshipJSON.wrap(["foo": "bar"])),
            triggers: [.event(EventAutomationTrigger(id: "json-id", type: .customEventCount, goal: 1.0))],
            created: Date(timeIntervalSince1970: 1703073600),
            lastUpdated: Date(timeIntervalSince1970: 1703075400),
            group: "test_group",
            priority: 2,
            limit: 5,
            start: Date(timeIntervalSince1970: 1703030400),
            end: Date(timeIntervalSince1970: 1703116800),
            audience: AutomationAudience(audienceSelector: DeviceAudienceSelector()),
            delay: AutomationDelay(),
            interval: 3600,
            bypassHoldoutGroups: true,
            editGracePeriodDays: 7,
            metadata: [:],
            frequencyConstraintIDs: ["constraint1", "constraint2"],
            messageType: "test_type",
            additionalAudienceCheckOverrides: .init(bypass: true, context: "json-context", url: "https://result.url")
        )

        try verify(json: jsonString, expected: expectedSchedule)
    }

    /// The single-ID shape this field replaced still pools, so a payload written
    /// against the older shape does not silently lose its shared group.
    @Test
    func testParseLegacySingleSharedID() throws {
        let json = """
        {
           "id": "test_schedule",
           "type": "actions",
           "actions": { "foo": "bar" },
           "triggers": [],
           "ledger_config": {
              "shared_id": "group-1"
           }
        }
        """

        let decoded = try JSONDecoder().decode(AutomationSchedule.self, from: Data(json.utf8))
        #expect(decoded.ledgerSharedIDs == ["group-1"])
    }

    /// Both keys present: the current shape wins rather than merging, so a
    /// payload that carries `shared_id` for older SDKs does not widen the pool
    /// on newer ones.
    @Test
    func testCurrentSharedIDsWinOverLegacyKey() throws {
        let json = """
        {
           "id": "test_schedule",
           "type": "actions",
           "actions": { "foo": "bar" },
           "triggers": [],
           "ledger_config": {
              "shared_ids": ["group-1"],
              "shared_id": "legacy-group"
           }
        }
        """

        let decoded = try JSONDecoder().decode(AutomationSchedule.self, from: Data(json.utf8))
        #expect(decoded.ledgerSharedIDs == ["group-1"])
    }

    /// Re-encoding a schedule decoded from the legacy key emits the current
    /// shape, so the old spelling never round-trips back out.
    /// An explicitly empty `shared_ids` means "no pooling" and must not fall
    /// through to the legacy key, or a payload carrying both for mixed SDK
    /// versions would pool on new SDKs when it meant not to. An explicit null
    /// is treated as absent, so it does fall through.
    @Test
    func testEmptySharedIDsDoesNotFallBackToLegacyKey() throws {
        func decode(_ ledgerConfig: String) throws -> AutomationSchedule {
            let json = """
            { "id": "test_schedule", "type": "actions", "actions": { "foo": "bar" },
              "triggers": [], "ledger_config": \(ledgerConfig) }
            """
            return try JSONDecoder().decode(AutomationSchedule.self, from: Data(json.utf8))
        }

        #expect(try decode(#"{ "shared_ids": [], "shared_id": "legacy" }"#).ledgerSharedIDs == [])
        #expect(try decode(#"{ "shared_ids": null, "shared_id": "legacy" }"#).ledgerSharedIDs == ["legacy"])
        #expect(try decode(#"{ "shared_id": null }"#).ledgerSharedIDs == [])
    }

    @Test
    func testLegacySharedIDReencodesAsArray() throws {
        let json = """
        {
           "id": "test_schedule",
           "type": "actions",
           "actions": { "foo": "bar" },
           "triggers": [],
           "ledger_config": { "shared_id": "group-1" }
        }
        """

        let decoded = try JSONDecoder().decode(AutomationSchedule.self, from: Data(json.utf8))
        let reencoded = try JSONEncoder().encode(decoded)
        let body = try #require(String(data: reencoded, encoding: .utf8))

        #expect(body.contains("shared_ids"))
        #expect(!body.contains("\"shared_id\""))

        let roundTripped = try JSONDecoder().decode(
            AutomationSchedule.self,
            from: reencoded
        )
        #expect(roundTripped.ledgerSharedIDs == ["group-1"])
    }

    @Test
    func testParseLedgerConfig() throws {
        let jsonString = """
           {
               "id": "test_schedule",
               "triggers": [
                   { "type": "custom_event_count", "goal": 1, "id": "json-id" }
               ],
               "type": "actions",
               "actions": { "foo": "bar" },
               "ledger_config": {
                   "shared_ids": ["group-1"]
               }
           }
           """

        let expectedSchedule = AutomationSchedule(
            identifier: "test_schedule",
            data: .actions(try AirshipJSON.wrap(["foo": "bar"])),
            triggers: [.event(EventAutomationTrigger(id: "json-id", type: .customEventCount, goal: 1.0))],
            created: nil,
            ledgerConfig: AutomationSchedule.LedgerConfig(sharedIDs: ["group-1"])
        )

        try verify(json: jsonString, expected: expectedSchedule)

        let decoded = try JSONDecoder().decode(
            AutomationSchedule.self,
            from: jsonString.data(using: .utf8)!
        )
        #expect(decoded.ledgerSharedIDs == ["group-1"])
    }

    @Test
    func testParseAISuppression() throws {
        let jsonString = """
           {
               "id": "test_schedule",
               "triggers": [
                   { "type": "custom_event_count", "goal": 1, "id": "json-id" }
               ],
               "type": "actions",
               "actions": { "foo": "bar" },
               "ai_suppression": {
                   "condition": "user has not purchased in the last 30 days",
                   "subject_hints": { "tier": "gold" },
                   "miss_behavior": "penalize"
               }
           }
           """

        let expectedSchedule = AutomationSchedule(
            identifier: "test_schedule",
            data: .actions(try AirshipJSON.wrap(["foo": "bar"])),
            triggers: [.event(EventAutomationTrigger(id: "json-id", type: .customEventCount, goal: 1.0))],
            created: nil,
            aiSuppression: AutomationAISuppression(
                condition: "user has not purchased in the last 30 days",
                subjectHints: ["tier": "gold"],
                missBehavior: .penalize
            )
        )

        try verify(json: jsonString, expected: expectedSchedule)
    }

    @Test
    func testParseDeferred() throws {
        let jsonString = """
           {
               "id": "test_schedule",
               "triggers": [
                   {
                       "type": "custom_event_count",
                       "goal": 1,
                       "id": "json-id"
                   }
               ],
               "group": "test_group",
               "priority": 2,
               "limit": 5,
               "start": "2023-12-20T00:00:00Z",
               "end": "2023-12-21T00:00:00Z",
               "audience": {
                 "new_user": true,
                 "miss_behavior": "cancel"
               },
               "delay": {},
               "interval": 3600,
               "type": "deferred",
               "deferred": {
                   "url": "some:url",
                   "retry_on_timeout": true,
                   "type": "in_app_message"
               },
               "bypass_holdout_groups": true,
               "edit_grace_period": 7,
               "metadata": {},
               "frequency_constraint_ids": ["constraint1", "constraint2"],
               "message_type": "test_type",
               "last_updated": "2023-12-20T12:30:00Z",
               "created": "2023-12-20T12:00:00Z"
           }
           """


        let expectedSchedule = AutomationSchedule(
            identifier: "test_schedule",
            data: .deferred(DeferredAutomationData(url: URL(string:"some:url")!, retryOnTimeOut: true, type: .inAppMessage)),
            triggers: [.event(EventAutomationTrigger(id: "json-id", type: .customEventCount, goal: 1.0))],
            created: Date(timeIntervalSince1970: 1703073600),
            lastUpdated: Date(timeIntervalSince1970: 1703075400),
            group: "test_group",
            priority: 2,
            limit: 5,
            start: Date(timeIntervalSince1970: 1703030400),
            end: Date(timeIntervalSince1970: 1703116800),
            audience: AutomationAudience(audienceSelector: DeviceAudienceSelector(newUser: true), missBehavior: .cancel),
            delay: AutomationDelay(),
            interval: 3600,
            bypassHoldoutGroups: true,
            editGracePeriodDays: 7,
            metadata: [:],
            frequencyConstraintIDs: ["constraint1", "constraint2"],
            messageType: "test_type"
        )

        try verify(json: jsonString, expected: expectedSchedule)
    }

    @Test
    func testParseInAppMessage() throws {
        let jsonString = """
           {
               "id": "test_schedule",
               "triggers": [
                   {
                       "type": "custom_event_count",
                       "goal": 1,
                       "id": "json-id"
                   }
               ],
               "group": "test_group",
               "priority": 2,
               "limit": 5,
               "start": "2023-12-20T00:00:00Z",
               "end": "2023-12-21T00:00:00Z",
               "audience": {},
               "delay": {},
               "interval": 3600,
               "type": "in_app_message",
               "message": {
                   "source": "app-defined",
                   "display" : {
                       "cool": "story"
                   },
                   "display_type" : "custom",
                   "name" : "woot"
               },
               "bypass_holdout_groups": true,
               "edit_grace_period": 7,
               "metadata": {},
               "frequency_constraint_ids": ["constraint1", "constraint2"],
               "message_type": "test_type",
               "last_updated": "2023-12-20T12:30:00Z",
               "created": "2023-12-20T12:00:00Z"
           }
           """


        let message = InAppMessage(
            name: "woot",
            displayContent: .custom(
                ["cool": "story"]
            ),
            source: .appDefined
        )

        let expectedSchedule = AutomationSchedule(
            identifier: "test_schedule",
            data: .inAppMessage(message),
            triggers: [.event(EventAutomationTrigger(id: "json-id", type: .customEventCount, goal: 1.0))],
            created: Date(timeIntervalSince1970: 1703073600),
            lastUpdated: Date(timeIntervalSince1970: 1703075400),
            group: "test_group",
            priority: 2,
            limit: 5,
            start: Date(timeIntervalSince1970: 1703030400),
            end: Date(timeIntervalSince1970: 1703116800),
            audience: AutomationAudience(audienceSelector: DeviceAudienceSelector(), missBehavior: nil),
            delay: AutomationDelay(),
            interval: 3600,
            bypassHoldoutGroups: true,
            editGracePeriodDays: 7,
            metadata: [:],
            frequencyConstraintIDs: ["constraint1", "constraint2"],
            messageType: "test_type"
        )

        try verify(json: jsonString, expected: expectedSchedule)
    }
    
    @Test
    func testParseInAppMessageCompoundAudience() throws {
        let jsonString = """
           {
             "id": "test_schedule",
             "triggers": [
               {
                 "type": "custom_event_count",
                 "goal": 1,
                 "id": "json-id"
               }
             ],
             "group": "test_group",
             "priority": 2,
             "limit": 5,
             "start": "2023-12-20T00:00:00Z",
             "end": "2023-12-21T00:00:00Z",
             "compound_audience": {
               "selector": {
                 "type": "atomic",
                 "audience": {
                   "new_user": true
                 }
               },
               "miss_behavior": "skip"
             },
             "delay": {},
             "interval": 3600,
             "type": "in_app_message",
             "message": {
               "source": "app-defined",
               "display": {
                 "cool": "story"
               },
               "display_type": "custom",
               "name": "woot"
             },
             "bypass_holdout_groups": true,
             "edit_grace_period": 7,
             "metadata": {},
             "frequency_constraint_ids": [
               "constraint1",
               "constraint2"
             ],
             "message_type": "test_type",
             "last_updated": "2023-12-20T12:30:00Z",
             "created": "2023-12-20T12:00:00Z"
           }
           """


        let message = InAppMessage(
            name: "woot",
            displayContent: .custom(
                ["cool": "story"]
            ),
            source: .appDefined
        )

        let expectedSchedule = AutomationSchedule(
            identifier: "test_schedule",
            data: .inAppMessage(message),
            triggers: [.event(EventAutomationTrigger(id: "json-id", type: .customEventCount, goal: 1.0))],
            created: Date(timeIntervalSince1970: 1703073600),
            lastUpdated: Date(timeIntervalSince1970: 1703075400),
            group: "test_group",
            priority: 2,
            limit: 5,
            start: Date(timeIntervalSince1970: 1703030400),
            end: Date(timeIntervalSince1970: 1703116800),
            audience: nil,
            compoundAudience: AutomationCompoundAudience(
                selector: .atomic(.init(newUser: true)),
                missBehavior: .skip
            ),
            delay: AutomationDelay(),
            interval: 3600,
            bypassHoldoutGroups: true,
            editGracePeriodDays: 7,
            metadata: [:],
            frequencyConstraintIDs: ["constraint1", "constraint2"],
            messageType: "test_type"
        )

        try verify(json: jsonString, expected: expectedSchedule)
    }

    func verify(json: String, expected: AutomationSchedule) throws {
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()

        let fromJSON = try decoder.decode(AutomationSchedule.self, from: json.data(using: .utf8)!)
        #expect(fromJSON == expected)

        let roundTrip = try decoder.decode(AutomationSchedule.self, from: try encoder.encode(fromJSON))
        #expect(roundTrip == fromJSON)
    }

}

