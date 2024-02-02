/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipAutomationSwift
import AirshipCore

class AutomationScheduleTests: XCTestCase {

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
               "created": "2023-12-20T12:00:00Z"
           }
           """

        let expectedSchedule = AutomationSchedule(
            identifier: "test_schedule",
            data: .actions(try AirshipJSON.wrap(["foo": "bar"])),
            triggers: [AutomationTrigger(id: "json-id", type: .customEventCount, goal: 1.0)],
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
            metadata: .object([:]),
            frequencyConstraintIDs: ["constraint1", "constraint2"],
            messageType: "test_type"
        )

        try verify(json: jsonString, expected: expectedSchedule)
    }

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
            triggers: [AutomationTrigger(id: "json-id", type: .customEventCount, goal: 1.0)],
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
            metadata: .object([:]),
            frequencyConstraintIDs: ["constraint1", "constraint2"],
            messageType: "test_type"
        )

        try verify(json: jsonString, expected: expectedSchedule)
    }

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
                AirshipJSON.object(["cool": .string("story")])
            ),
            source: .appDefined
        )

        let expectedSchedule = AutomationSchedule(
            identifier: "test_schedule",
            data: .inAppMessage(message),
            triggers: [AutomationTrigger(id: "json-id", type: .customEventCount, goal: 1.0)],
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
            metadata: .object([:]),
            frequencyConstraintIDs: ["constraint1", "constraint2"],
            messageType: "test_type"
        )

        try verify(json: jsonString, expected: expectedSchedule)
    }

    func verify(json: String, expected: AutomationSchedule) throws {
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()

        let fromJSON = try decoder.decode(AutomationSchedule.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(fromJSON, expected)

        let roundTrip = try decoder.decode(AutomationSchedule.self, from: try encoder.encode(fromJSON))
        XCTAssertEqual(roundTrip, fromJSON)
    }

}

