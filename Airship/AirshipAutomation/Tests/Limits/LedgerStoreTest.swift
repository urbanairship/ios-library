/* Copyright Airship and Contributors */

import Testing
import Foundation
@testable @_spi(AirshipInternal) import AirshipAutomation

struct LedgerStoreTest {

    private let store: LedgerStore = LedgerStore(
        appKey: UUID().uuidString,
        inMemory: true
    )

    private func triggered(
        scheduleID: String,
        sharedID: String? = nil,
        triggerID: String? = nil,
        timestamp: Date = Date(timeIntervalSince1970: 0),
        count: Int? = nil
    ) -> LedgerEvent {
        return .triggered(
            .init(
                scheduleID: scheduleID,
                sharedID: sharedID,
                triggerID: triggerID,
                timestamp: timestamp,
                count: count
            )
        )
    }

    private func execution(
        scheduleID: String,
        sharedID: String? = nil,
        triggerID: String? = nil,
        timestamp: Date = Date(timeIntervalSince1970: 0),
        count: Int? = nil,
        result: LedgerExecutionResult = .succeeded,
        cancel: Bool? = nil
    ) -> LedgerEvent {
        return .execution(
            .init(
                scheduleID: scheduleID,
                sharedID: sharedID,
                triggerID: triggerID,
                timestamp: timestamp,
                count: count,
                result: result,
                cancel: cancel
            )
        )
    }

    @Test
    func testRecordAndQueryBySchedule() async throws {
        let event = execution(scheduleID: "schedule-1")
        try await store.recordEvents([event])

        let result = try await store.events(scheduleID: "schedule-1", sharedID: nil)
        #expect(result == [event])
    }

    @Test
    func testQueryReturnsEmptyWhenNoMatch() async throws {
        try await store.recordEvents([execution(scheduleID: "schedule-1")])

        let result = try await store.events(scheduleID: "other", sharedID: nil)
        #expect(result.isEmpty)
    }

    @Test
    func testQueryMatchesScheduleOrSharedID() async throws {
        // Recorded by another schedule but under the shared group.
        let sharedEvent = execution(scheduleID: "schedule-2", sharedID: "group-1")
        // Recorded by this schedule with no shared group.
        let ownEvent = execution(scheduleID: "schedule-1")
        // Unrelated.
        let unrelated = execution(scheduleID: "schedule-3", sharedID: "group-2")

        try await store.recordEvents([sharedEvent, ownEvent, unrelated])

        let result = try await store.events(scheduleID: "schedule-1", sharedID: "group-1")
        #expect(Set(result) == Set([sharedEvent, ownEvent]))
    }

    @Test
    func testQueryIgnoresSharedWhenNil() async throws {
        let sharedEvent = execution(scheduleID: "schedule-2", sharedID: "group-1")
        let ownEvent = execution(scheduleID: "schedule-1", sharedID: "group-1")

        try await store.recordEvents([sharedEvent, ownEvent])

        // Without a shared ID, only the schedule's own events are eligible.
        let result = try await store.events(scheduleID: "schedule-1", sharedID: nil)
        #expect(result == [ownEvent])
    }

    @Test
    func testRecordEmptyIsNoop() async throws {
        try await store.recordEvents([])
        let result = try await store.events(scheduleID: "schedule-1", sharedID: "group-1")
        #expect(result.isEmpty)
    }

    @Test
    func testDeleteByScheduleScope() async throws {
        let keep = execution(scheduleID: "schedule-2", sharedID: "group-1")
        let remove = execution(scheduleID: "schedule-1", sharedID: "group-1")
        try await store.recordEvents([keep, remove])

        try await store.deleteEvents(scopes: [.schedule("schedule-1")])

        let result = try await store.events(scheduleID: "schedule-1", sharedID: "group-1")
        #expect(result == [keep])
    }

    @Test
    func testDeleteBySharedScope() async throws {
        let removeA = execution(scheduleID: "schedule-1", sharedID: "group-1")
        let removeB = execution(scheduleID: "schedule-2", sharedID: "group-1")
        let keep = execution(scheduleID: "schedule-3")
        try await store.recordEvents([removeA, removeB, keep])

        try await store.deleteEvents(scopes: [.shared("group-1")])

        #expect(try await store.events(scheduleID: "schedule-1", sharedID: "group-1").isEmpty)
        #expect(try await store.events(scheduleID: "schedule-2", sharedID: "group-1").isEmpty)
        #expect(try await store.events(scheduleID: "schedule-3", sharedID: nil) == [keep])
    }

    @Test
    func testDeleteMultipleScopes() async throws {
        let removeA = execution(scheduleID: "schedule-1")
        let removeB = execution(scheduleID: "schedule-2", sharedID: "group-1")
        let keep = execution(scheduleID: "schedule-3")
        try await store.recordEvents([removeA, removeB, keep])

        try await store.deleteEvents(
            scopes: [.schedule("schedule-1"), .shared("group-1")]
        )

        #expect(try await store.events(scheduleID: "schedule-1", sharedID: nil).isEmpty)
        #expect(try await store.events(scheduleID: "schedule-2", sharedID: "group-1").isEmpty)
        #expect(try await store.events(scheduleID: "schedule-3", sharedID: nil) == [keep])
    }

    @Test
    func testDeleteEmptyScopesIsNoop() async throws {
        let event = execution(scheduleID: "schedule-1")
        try await store.recordEvents([event])

        try await store.deleteEvents(scopes: [])

        #expect(try await store.events(scheduleID: "schedule-1", sharedID: nil) == [event])
    }

    @Test
    func testPersistsAllFields() async throws {
        let triggeredEvent = triggered(
            scheduleID: "schedule-1",
            sharedID: "group-1",
            triggerID: "trigger-1",
            timestamp: Date(timeIntervalSince1970: 123),
            count: 3
        )
        let executionEvent = execution(
            scheduleID: "schedule-1",
            sharedID: "group-1",
            triggerID: "trigger-2",
            timestamp: Date(timeIntervalSince1970: 456),
            count: 5,
            result: .audienceMiss,
            cancel: true
        )

        try await store.recordEvents([triggeredEvent, executionEvent])

        let result = try await store.events(scheduleID: "schedule-1", sharedID: "group-1")
        #expect(Set(result) == Set([triggeredEvent, executionEvent]))
    }

    @Test
    func testEventCodableRoundTrip() throws {
        let events: [LedgerEvent] = [
            triggered(scheduleID: "s", sharedID: "g", triggerID: "t", count: 2),
            execution(scheduleID: "s", result: .backfill, cancel: false)
        ]

        for event in events {
            let data = try JSONEncoder().encode(event)
            let decoded = try JSONDecoder().decode(LedgerEvent.self, from: data)
            #expect(decoded == event)
        }
    }
}
