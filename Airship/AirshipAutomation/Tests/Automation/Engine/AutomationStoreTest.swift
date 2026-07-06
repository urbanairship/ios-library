/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable @_spi(AirshipInternal)
import AirshipAutomation
@_spi(AirshipInternal) import AirshipCore

struct AutomationStoreTest {

    private let store: AutomationStore = AutomationStore(
        appKey: UUID().uuidString,
        inMemory: true
    )

    @Test
    func testUpsertNewSchedules() async throws {
        let data = ["foo": makeSchedule(identifer: "foo"), "bar": makeSchedule(identifer: "bar")]

        let result = try await self.store.upsertSchedules(scheduleIDs: ["foo", "bar"]) { identifier, existing in
            #expect(existing == nil)
            return data[identifier]!
        }

        #expect(result == [data["foo"], data["bar"]])
    }

    @Test
    func testUpsertMixedSchedules() async throws {
        let original = ["foo": makeSchedule(identifer: "foo"), "bar": makeSchedule(identifer: "bar")]

        var result = try await self.store.upsertSchedules(scheduleIDs: ["foo", "bar"]) { identifier, existing in
            #expect(existing == nil)
            return original[identifier]!
        }

        #expect(result == [original["foo"], original["bar"]])

        var updated = original
        updated["baz"] = makeSchedule(identifer: "baz")
        updated["foo"]?.scheduleState = .finished

        result = try await self.store.upsertSchedules(scheduleIDs: ["foo", "bar", "baz"]) { [updated] identifier, existing in
            if let existing = existing {
                #expect(existing.equalsIgnoringLastModified(original[identifier]!))
            }
            return updated[identifier]!
        }

        #expect(result == [updated["foo"], updated["bar"], updated["baz"]])
    }

    @Test
    func testUpdate() async throws {
        let originalFoo = makeSchedule(identifer: "foo")

        _ = try await self.store.upsertSchedules(scheduleIDs: ["foo"]) { identifier, existing in
            return originalFoo
        }

        let triggerInfo = TriggeringInfo(
            context: AirshipTriggerContext(type: "foo", goal: 10.0, event: "event"),
            date: Date.distantPast
        )

        let preparedInfo = PreparedScheduleInfo(
            scheduleID: "full",
            productID: "some product",
            campaigns: "campaigns",
            contactID: "some contact",
            experimentResult: ExperimentResult(
                channelID: "some channel",
                contactID: "some contact",
                isMatch: true,
                reportingMetadata: [AirshipJSON.string("reporing")]
            ),
            triggerSessionID: "some trigger session id",
            priority: 0
        )

        let date = Date()
        let result = try await self.store.updateSchedule(scheduleID: "foo") { data in
            data.executionCount = 100
            data.triggerInfo = triggerInfo
            data.schedule.group = "bar"
            data.preparedScheduleInfo = preparedInfo
            data.scheduleState = .paused
            data.scheduleStateChangeDate = date
        }

        var expected = originalFoo
        expected.schedule.group = "bar"
        expected.executionCount = 100
        expected.triggerInfo = triggerInfo
        expected.preparedScheduleInfo = preparedInfo
        expected.scheduleStateChangeDate = date
        expected.scheduleState = .paused
        #expect(result!.equalsIgnoringLastModified(expected))
    }

    @Test
    func testUpsertFullData() async throws {
        var schedule = self.makeSchedule(identifer: "full")
        schedule.triggerInfo = TriggeringInfo(
            context: AirshipTriggerContext(type: "foo", goal: 10.0, event: "event"),
            date: Date.distantPast
        )

        schedule.preparedScheduleInfo = PreparedScheduleInfo(
            scheduleID: "full",
            productID: "some product",
            campaigns: "campaigns",
            contactID: "some contact",
            experimentResult: ExperimentResult(
                channelID: "some channel",
                contactID: "some contact",
                isMatch: true,
                reportingMetadata: [AirshipJSON.string("reporing")]
            ),
            triggerSessionID: "some trigger session id",
            priority: 0
        )


        let batchUpsertResult = try await self.store.upsertSchedules(scheduleIDs: ["full"]) { [schedule] identifier, existing in
            return schedule
        }

        #expect(batchUpsertResult.count == 1)

        let fetchResult = try await self.store.getSchedule(scheduleID: "full")
        #expect(fetchResult != nil)
        #expect(fetchResult!.lastScheduleModifiedDate >= batchUpsertResult[0].lastScheduleModifiedDate)
    }

    @Test
    func testUpdateDoesNotExist() async throws {
        let result = try await self.store.updateSchedule(scheduleID: "baz") { data in
            Issue.record()
        }

        #expect(result == nil)
    }

    @Test
    func testGetSchedules() async throws {
        let original = ["foo": makeSchedule(identifer: "foo"), "bar": makeSchedule(identifer: "bar")]
        let _ = try await self.store.upsertSchedules(scheduleIDs: ["foo", "bar"]) { identifier, existing in
            return original[identifier]!
        }

        let foo = try await self.store.getSchedule(scheduleID: "foo")
        #expect(foo!.equalsIgnoringLastModified(original["foo"]!))

        let bar = try await self.store.getSchedule(scheduleID: "bar")
        #expect(bar!.equalsIgnoringLastModified(original["bar"]!))

        let doesNotExist = try await self.store.getSchedule(scheduleID: "doesNotExist")
        #expect(doesNotExist == nil)
    }

    @Test
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
            return l.schedule.identifier > r.schedule.identifier
        }

        #expect([original["foo"]!, original["baz"]!].equalsIgnoringLastModified(groupA))
    }

    @Test
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
            return l.schedule.identifier > r.schedule.identifier
        }

        #expect([original["baz"]!, original["bar"]!].equalsIgnoringLastModified(remaining))
    }

    @Test
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
            return l.schedule.identifier > r.schedule.identifier
        }

        #expect([original["bar"]!].equalsIgnoringLastModified(remaining))
    }

    @Test
    func testAssociatedData() async throws {
        let associatedData = try AirshipJSON.string("some data").toData()
        var schedule = self.makeSchedule(identifer: "bar")
        schedule.associatedData = associatedData

        let _ = try await self.store.upsertSchedules(scheduleIDs: ["bar"]) { [schedule] identifier, existing in
            return schedule
        }

        let fromStore = try await self.store.getAssociatedData(scheduleID: "bar")

        #expect(fromStore == associatedData)
    }

    @Test
    func testAssociatedDataNull() async throws {
        let schedule = self.makeSchedule(identifer: "bar")

        let _ = try await self.store.upsertSchedules(scheduleIDs: ["bar"]) { [schedule] identifier, existing in
            return schedule
        }

        let fromStore = try await self.store.getAssociatedData(scheduleID: "bar")

        #expect(fromStore == nil)
    }

    @Test
    func testAssociatedNoSchedule() async throws {
        let fromStore = try await self.store.getAssociatedData(scheduleID: "bar")
        #expect(fromStore == nil)
    }

    @Test
    func testIsCurrent() async throws {
        let schedule = makeSchedule(identifer: "test")
        let _ = try await self.store.upsertSchedules(scheduleIDs: ["test"]) { identifier, existing in
            return schedule
        }

        let fullSchedule = try await self.store.getSchedule(scheduleID: "test")!

        var isCurrent = try await self.store.isCurrent(
            scheduleID: "test",
            lastScheduleModifiedDate: fullSchedule.lastScheduleModifiedDate,
            scheduleState: .idle
        )
        #expect(isCurrent)

        isCurrent = try await self.store.isCurrent(
            scheduleID: "test",
            lastScheduleModifiedDate: fullSchedule.lastScheduleModifiedDate,
            scheduleState: .paused
        )
        #expect(!(isCurrent))

        isCurrent = try await self.store.isCurrent(
            scheduleID: "test",
            lastScheduleModifiedDate: fullSchedule.lastScheduleModifiedDate.addingTimeInterval(1),
            scheduleState: .idle
        )
        #expect(!(isCurrent))
    }

    @Test
    func testIsCurrentNoSchedule() async throws {
        let isCurrent = try await self.store.isCurrent(
            scheduleID: "fake identifier",
            lastScheduleModifiedDate: Date(),
            scheduleState: .paused
        )
        #expect(!(isCurrent))
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
            schedule: schedule,
            scheduleState: .idle,
            lastScheduleModifiedDate: .distantPast,
            scheduleStateChangeDate: Date.distantPast,
            executionCount: 0,
            triggerSessionID: UUID().uuidString
        )
    }
}

extension [AutomationScheduleData] {
    func equalsIgnoringLastModified(_ other: [AutomationScheduleData]) -> Bool {
        guard count == other.count else { return false }
        return zip(self, other).allSatisfy { $0.equalsIgnoringLastModified($1) }
    }
}

extension AutomationScheduleData {
    func equalsIgnoringLastModified(_ other: AutomationScheduleData) -> Bool {
        schedule == other.schedule &&
        scheduleState == other.scheduleState &&
        scheduleStateChangeDate == other.scheduleStateChangeDate &&
        executionCount == other.executionCount &&
        triggerInfo == other.triggerInfo &&
        preparedScheduleInfo == other.preparedScheduleInfo &&
        associatedData == other.associatedData &&
        triggerSessionID == other.triggerSessionID
    }
}
