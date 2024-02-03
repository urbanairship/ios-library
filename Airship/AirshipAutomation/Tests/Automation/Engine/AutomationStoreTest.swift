/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipAutomation
import AirshipCore

final class AutomationStoreTest: XCTestCase {

    private let store: AutomationStore = AutomationStore(
        appKey: UUID().uuidString,
        inMemory: true
    )

    func testUpsertNewSchedules() async throws {
        let data = ["foo": makeSchedule(identifer: "foo"), "bar": makeSchedule(identifer: "bar")]

        let result = try await self.store.upsertSchedules(scheduleIDs: ["foo", "bar"]) { identifier, existing in
            XCTAssertNil(existing)
            return data[identifier]!
        }

        XCTAssertEqual(result, [data["foo"], data["bar"]])
    }

    func testUpsertMixedSchedules() async throws {
        let original = ["foo": makeSchedule(identifer: "foo"), "bar": makeSchedule(identifer: "bar")]

        var result = try await self.store.upsertSchedules(scheduleIDs: ["foo", "bar"]) { identifier, existing in
            XCTAssertNil(existing)
            return original[identifier]!
        }

        XCTAssertEqual(result, [original["foo"], original["bar"]])

        var updated = original
        updated["baz"] = makeSchedule(identifer: "baz")
        updated["foo"]?.scheduleState = .finished

        result = try await self.store.upsertSchedules(scheduleIDs: ["foo", "bar", "baz"]) { [updated] identifier, existing in
            XCTAssertEqual(existing, original[identifier])
            return updated[identifier]!
        }

        XCTAssertEqual(result, [updated["foo"], updated["bar"], updated["baz"]])
    }

    func testUpdate() async throws {
        let originalFoo = makeSchedule(identifer: "foo")

        _ = try await self.store.upsertSchedules(scheduleIDs: ["foo"]) { identifier, existing in
            return originalFoo
        }

        let result = try await self.store.updateSchedule(scheduleID: "foo") { data in
            data.group = "bar"
        }

        var expected = originalFoo
        expected.group = "bar"
        XCTAssertEqual(result, expected)
    }

    func testUpsertFullData() async throws {
        var schedule = self.makeSchedule(identifer: "full")
        schedule.triggerInfo = TriggeringInfo(
            context: AirshipTriggerContext(type: "foo", goal: 10.0, event: .string("event")),
            date: Date.distantPast
        )

        schedule.preparedScheduleInfo = PreparedScheduleInfo(
            scheduleID: "full",
            productID: "some product",
            campaigns: .string("campaigns"),
            contactID: "some contact",
            experimentResult: ExperimentResult(
                channelID: "some channel",
                contactID: "some contact",
                isMatch: true,
                reportingMetadata: [AirshipJSON.string("reporing")]
            )
        )

        let batchUpsertResult = try await self.store.upsertSchedules(scheduleIDs: ["full"]) { [schedule] identifier, existing in
            return schedule
        }

        XCTAssertEqual([schedule], batchUpsertResult)

        let fetchResult = try await self.store.getSchedule(scheduleID: "full")
        XCTAssertEqual(schedule, fetchResult)
    }

    func testUpdateDoesNotExist() async throws {
        let result = try await self.store.updateSchedule(scheduleID: "baz") { data in
            XCTFail()
        }

        XCTAssertNil(result)
    }

    func testGetSchedules() async throws {
        let original = ["foo": makeSchedule(identifer: "foo"), "bar": makeSchedule(identifer: "bar")]
        let _ = try await self.store.upsertSchedules(scheduleIDs: ["foo", "bar"]) { identifier, existing in
            return original[identifier]!
        }

        let foo = try await self.store.getSchedule(scheduleID: "foo")
        XCTAssertEqual(foo, original["foo"])

        let bar = try await self.store.getSchedule(scheduleID: "bar")
        XCTAssertEqual(bar, original["bar"])

        let doesNotExist = try await self.store.getSchedule(scheduleID: "doesNotExist")
        XCTAssertNil(doesNotExist)
    }

    func testGetSchedulesByGroup() async throws {
        let original = [
            "foo": makeSchedule(identifer: "foo", group: "groupA"),
            "bar": makeSchedule(identifer: "bar"),
            "baz": makeSchedule(identifer: "baz", group: "groupA")
        ]

        let _ = try await self.store.upsertSchedules(scheduleIDs: ["foo", "bar", "baz"]) { identifier, existing in
            return original[identifier]!
        }

        let groupA = try await self.store.getSchedules(group: "groupA").sorted { l, r in
            return l.identifier > r.identifier
        }

        XCTAssertEqual([original["foo"], original["baz"]], groupA)
    }

    func testDeleteIdentifiers() async throws {
        let original = [
            "foo": makeSchedule(identifer: "foo", group: "groupA"),
            "bar": makeSchedule(identifer: "bar"),
            "baz": makeSchedule(identifer: "baz", group: "groupA")
        ]

        let _ = try await self.store.upsertSchedules(scheduleIDs: ["foo", "bar", "baz"]) { identifier, existing in
            return original[identifier]!
        }

        try await self.store.deleteSchedules(scheduleIDs: ["foo", "doesNotExist"])

        let remaining = try await self.store.getSchedules().sorted { l, r in
            return l.identifier > r.identifier
        }

        XCTAssertEqual([original["baz"], original["bar"]], remaining)
    }

    func testDeleteGroup() async throws {
        let original = [
            "foo": makeSchedule(identifer: "foo", group: "groupA"),
            "bar": makeSchedule(identifer: "bar", group: "groupB"),
            "baz": makeSchedule(identifer: "baz", group: "groupA")
        ]

        let _ = try await self.store.upsertSchedules(scheduleIDs: ["foo", "bar", "baz"]) { identifier, existing in
            return original[identifier]!
        }

        try await self.store.deleteSchedules(group: "groupA")

        let remaining = try await self.store.getSchedules().sorted { l, r in
            return l.identifier > r.identifier
        }

        XCTAssertEqual([original["bar"]], remaining)
    }

    private func makeSchedule(identifer: String, group: String? = nil) -> AutomationScheduleData {
        let schedule = AutomationSchedule(
            identifier: identifer,
            data: .inAppMessage(
                InAppMessage(
                    name: "some name",
                    displayContent: .custom(.string("Custom"))
                )
            ),
            triggers: [],
            created: Date.distantPast,
            group: group
        )

        return AutomationScheduleData(
            identifier: identifer,
            group: group,
            schedule: schedule,
            scheduleState: .idle,
            scheduleStateChangeDate: Date.distantPast
        )
    }
}
