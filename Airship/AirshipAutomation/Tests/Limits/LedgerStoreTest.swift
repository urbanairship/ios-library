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

    // MARK: - Retention

    @Test
    func testRetainKeepsLiveScheduleAndDropsOrphans() async throws {
        let liveOwn = execution(scheduleID: "live")
        let liveViaGroup = execution(scheduleID: "dead-1", sharedID: "live-group")
        let orphanWithGroup = execution(scheduleID: "dead-2", sharedID: "dead-group")
        let orphanNoGroup = execution(scheduleID: "dead-3")

        try await store.recordEvents([liveOwn, liveViaGroup, orphanWithGroup, orphanNoGroup])

        try await store.retainEvents(
            liveScheduleIDs: ["live"],
            liveSharedIDs: ["live-group"]
        )

        // Kept: own event of a live schedule, and an event pooled under a live group.
        #expect(try await store.events(scheduleID: "live", sharedID: nil) == [liveOwn])
        #expect(
            try await store.events(scheduleID: "dead-1", sharedID: "live-group") == [liveViaGroup]
        )
        // Dropped: fully orphaned events, including one with no shared group.
        #expect(try await store.events(scheduleID: "dead-2", sharedID: "dead-group").isEmpty)
        #expect(try await store.events(scheduleID: "dead-3", sharedID: nil).isEmpty)
    }

    @Test
    func testRetainWithNoLiveIDsDropsEverything() async throws {
        try await store.recordEvents([
            execution(scheduleID: "a"),
            execution(scheduleID: "b", sharedID: "g")
        ])

        try await store.retainEvents(liveScheduleIDs: [], liveSharedIDs: [])

        #expect(try await store.events(scheduleID: "a", sharedID: "g").isEmpty)
        #expect(try await store.events(scheduleID: "b", sharedID: "g").isEmpty)
    }

    // MARK: - Compaction (store)

    @Test
    func testCompactMergesMergeableRows() async throws {
        let now = Self.date(2020, 1, 1)
        try await store.recordEvents([
            execution(scheduleID: "s", timestamp: Self.date(2017, 3, 5)),
            execution(scheduleID: "s", timestamp: Self.date(2017, 9, 20))
        ])

        try await store.compact(now: now)

        let result = try await store.events(scheduleID: "s", sharedID: nil)
        #expect(result.count == 1)
        #expect(result.first?.count == 2)
        #expect(result.first?.timestamp == Self.date(2017, 9, 20))
    }

    // When the ledger is under the cap and every event is younger than a year,
    // the cheap pre-check skips the decode entirely. Two recent events sharing an
    // exact timestamp would merge in the raw tier if compaction ran, so their
    // survival proves the guard short-circuited before decoding.
    @Test
    func testCompactSkipsWhenAllRecentAndUnderCap() async throws {
        let now = Self.date(2020, 1, 1)
        let recent = Self.date(2019, 12, 25)
        try await store.recordEvents([
            execution(scheduleID: "s", timestamp: recent),
            execution(scheduleID: "s", timestamp: recent)
        ])

        try await store.compact(now: now)

        let result = try await store.events(scheduleID: "s", sharedID: nil)
        #expect(result.count == 2)
    }

    // Over the cap, the pre-check must not short-circuit even when every event is
    // recent: the backstop still has to run. Two recent same-timestamp events
    // merge in the raw tier once the decode proceeds.
    @Test
    func testCompactOverCapCompactsEvenWhenRecent() async throws {
        let now = Self.date(2020, 1, 1)
        let recent = Self.date(2019, 12, 25)
        try await store.recordEvents([
            execution(scheduleID: "s", timestamp: recent),
            execution(scheduleID: "s", timestamp: recent)
        ])

        try await store.compact(now: now, maxEvents: 1)

        let result = try await store.events(scheduleID: "s", sharedID: nil)
        #expect(result.count == 1)
        #expect(result.first?.count == 2)
    }

    // When any event is old enough to age-bucket, the pre-check lets the decode
    // proceed, so a full compaction runs over the whole table — which also merges
    // recent same-timestamp dupes that a skipped run would have left alone.
    @Test
    func testCompactProceedsWhenAnyEventIsOld() async throws {
        let now = Self.date(2020, 1, 1)
        let recent = Self.date(2019, 12, 25)
        try await store.recordEvents([
            execution(scheduleID: "s", timestamp: recent),
            execution(scheduleID: "s", timestamp: recent),
            execution(scheduleID: "old", timestamp: Self.date(2017, 3, 5))
        ])

        try await store.compact(now: now)

        let recentResult = try await store.events(scheduleID: "s", sharedID: nil)
        #expect(recentResult.count == 1)
        #expect(recentResult.first?.count == 2)
    }

    // MARK: - Compaction (pure)

    @Test
    func testCompactRawTierKeepsRecentDistinctTimestamps() {
        let now = Self.date(2020, 1, 1)
        let events = [
            execution(scheduleID: "s", timestamp: Self.date(2019, 12, 20)),
            execution(scheduleID: "s", timestamp: Self.date(2019, 12, 25))
        ]

        // Both younger than a year: raw, so distinct timestamps never merge.
        #expect(LedgerCompactor.compact(events, now: now).count == 2)
    }

    @Test
    func testCompactMonthlyTierMergesWithinSameMonth() {
        let now = Self.date(2020, 1, 1)
        let events = [
            execution(scheduleID: "s", timestamp: Self.date(2018, 6, 10), count: 2),
            execution(scheduleID: "s", timestamp: Self.date(2018, 6, 20), count: 3)
        ]

        let result = LedgerCompactor.compact(events, now: now)
        #expect(result.count == 1)
        #expect(result.first?.count == 5)
        #expect(result.first?.timestamp == Self.date(2018, 6, 20))
    }

    @Test
    func testCompactMonthlyTierKeepsDifferentMonths() {
        let now = Self.date(2020, 1, 1)
        let events = [
            execution(scheduleID: "s", timestamp: Self.date(2018, 6, 10)),
            execution(scheduleID: "s", timestamp: Self.date(2018, 7, 10))
        ]

        #expect(LedgerCompactor.compact(events, now: now).count == 2)
    }

    @Test
    func testCompactYearlyTierMergesWithinSameYear() {
        let now = Self.date(2020, 1, 1)
        let events = [
            execution(scheduleID: "s", timestamp: Self.date(2017, 3, 5)),
            execution(scheduleID: "s", timestamp: Self.date(2017, 9, 20))
        ]

        let result = LedgerCompactor.compact(events, now: now)
        #expect(result.count == 1)
        #expect(result.first?.count == 2)
        #expect(result.first?.timestamp == Self.date(2017, 9, 20))
    }

    @Test
    func testCompactNeverMergesAcrossDistinguishingFields() {
        let now = Self.date(2020, 1, 1)
        let old = Self.date(2017, 3, 5)
        let older = Self.date(2017, 9, 20)

        // Same yearly bucket + scope, but each pair differs on one field the
        // limit evaluator can key on, so none may merge.
        let differByResult = [
            execution(scheduleID: "s", timestamp: old, result: .succeeded),
            execution(scheduleID: "s", timestamp: older, result: .audienceMiss)
        ]
        let differByCancel = [
            execution(scheduleID: "s", timestamp: old, cancel: true),
            execution(scheduleID: "s", timestamp: older, cancel: false)
        ]
        let differByTrigger = [
            execution(scheduleID: "s", triggerID: "t1", timestamp: old),
            execution(scheduleID: "s", triggerID: "t2", timestamp: older)
        ]
        let differByScope = [
            execution(scheduleID: "s1", timestamp: old),
            execution(scheduleID: "s2", timestamp: older)
        ]
        let differByType = [
            triggered(scheduleID: "s", timestamp: old),
            execution(scheduleID: "s", timestamp: older)
        ]

        for events in [differByResult, differByCancel, differByTrigger, differByScope, differByType] {
            #expect(LedgerCompactor.compact(events, now: now).count == 2)
        }
    }

    @Test
    func testCompactBackstopCollapsesOldestGroupFirst() {
        let now = Self.date(2020, 1, 1)
        // Two raw (recent) groups of 3 distinct-timestamp events each = 6 rows.
        // Group "a" is older than group "b".
        let events = [
            execution(scheduleID: "a", timestamp: Self.date(2019, 7, 1)),
            execution(scheduleID: "a", timestamp: Self.date(2019, 7, 2)),
            execution(scheduleID: "a", timestamp: Self.date(2019, 7, 3)),
            execution(scheduleID: "b", timestamp: Self.date(2019, 11, 1)),
            execution(scheduleID: "b", timestamp: Self.date(2019, 11, 2)),
            execution(scheduleID: "b", timestamp: Self.date(2019, 11, 3))
        ]

        let result = LedgerCompactor.compact(events, now: now, maxEvents: 4)

        #expect(result.count == 4)

        // Oldest group fully collapsed to one summed event...
        let groupA = result.filter { $0.scheduleID == "a" }
        #expect(groupA.count == 1)
        #expect(groupA.first?.count == 3)
        // ...while the newer group is left untouched.
        #expect(result.filter { $0.scheduleID == "b" }.count == 3)
    }

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return LedgerCompactor.utcCalendar.date(from: components)!
    }
}
