/* Copyright Airship and Contributors */

import Testing
import CoreData
import Foundation
@testable @_spi(AirshipInternal) import AirshipAutomation

/// Where `UACoreData` puts a `LedgerStore`'s SQLite files, given its `appKey`.
fileprivate func ledgerStoreFileURL(appKey: String) -> URL? {
    return FileManager.default
        .urls(for: .libraryDirectory, in: .userDomainMask).last?
        .appendingPathComponent("com.urbanairship.no-backup")
        .appendingPathComponent("AirshipLedger-\(appKey).sqlite")
}

/// Deletes each app key's store file and its `-wal`/`-shm` siblings, ignoring
/// anything not present. Best-effort and non-throwing so it can run from a
/// `deinit`, matching the cleanup pattern from #4006.
fileprivate func removeLedgerStoreFiles(appKeys: [String]) {
    for appKey in appKeys {
        guard let url = ledgerStoreFileURL(appKey: appKey) else { continue }
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(atPath: url.path + suffix)
        }
    }
}

struct LedgerStoreTest {

    private let store: LedgerStore = LedgerStore(
        appKey: UUID().uuidString,
        inMemory: true
    )

    private func triggered(
        scheduleID: String,
        sharedIDs: [String] = [],
        triggerID: String? = nil,
        variantAudienceID: String? = nil,
        timestamp: Date = Date(timeIntervalSince1970: 0),
        count: Int? = nil
    ) -> LedgerEvent {
        return .triggered(
            .init(
                scheduleID: scheduleID,
                sharedIDs: sharedIDs.isEmpty ? nil : sharedIDs,
                triggerID: triggerID,
                variantAudienceID: variantAudienceID,
                timestamp: timestamp,
                count: count
            )
        )
    }

    private func execution(
        scheduleID: String,
        sharedIDs: [String] = [],
        triggerID: String? = nil,
        variantAudienceID: String? = nil,
        timestamp: Date = Date(timeIntervalSince1970: 0),
        count: Int? = nil,
        result: LedgerExecutionResult = .succeeded,
        cancel: Bool? = nil
    ) -> LedgerEvent {
        return .execution(
            .init(
                scheduleID: scheduleID,
                sharedIDs: sharedIDs.isEmpty ? nil : sharedIDs,
                triggerID: triggerID,
                variantAudienceID: variantAudienceID,
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

        let result = try await store.events(scheduleID: "schedule-1", sharedIDs: [])
        #expect(result == [event])
    }

    @Test
    func testQueryReturnsEmptyWhenNoMatch() async throws {
        try await store.recordEvents([execution(scheduleID: "schedule-1")])

        let result = try await store.events(scheduleID: "other", sharedIDs: [])
        #expect(result.isEmpty)
    }

    @Test
    func testQueryMatchesScheduleOrSharedID() async throws {
        // Recorded by another schedule but under the shared group.
        let sharedEvent = execution(scheduleID: "schedule-2", sharedIDs: ["group-1"])
        // Recorded by this schedule with no shared group.
        let ownEvent = execution(scheduleID: "schedule-1")
        // Unrelated.
        let unrelated = execution(scheduleID: "schedule-3", sharedIDs: ["group-2"])

        try await store.recordEvents([sharedEvent, ownEvent, unrelated])

        let result = try await store.events(scheduleID: "schedule-1", sharedIDs: ["group-1"])
        #expect(Set(result) == Set([sharedEvent, ownEvent]))
    }

    @Test
    func testQueryMatchesSharedIDAgainstBareScheduleID() async throws {
        // A schedule's pre-group history — e.g. backfilled pre-ledger events —
        // carries no sharedIDs at all, only its own scheduleID. A schedule that
        // names it via one of its shared_ids must still inherit it.
        let bareHistory = execution(scheduleID: "schedule-original")
        // Unrelated, must not match.
        let unrelated = execution(scheduleID: "schedule-3", sharedIDs: ["group-2"])

        try await store.recordEvents([bareHistory, unrelated])

        let result = try await store.events(scheduleID: "schedule-new", sharedIDs: ["schedule-original"])
        #expect(result == [bareHistory])
    }

    @Test
    func testQueryIgnoresSharedWhenNil() async throws {
        let sharedEvent = execution(scheduleID: "schedule-2", sharedIDs: ["group-1"])
        let ownEvent = execution(scheduleID: "schedule-1", sharedIDs: ["group-1"])

        try await store.recordEvents([sharedEvent, ownEvent])

        // Without a shared ID, only the schedule's own events are eligible.
        let result = try await store.events(scheduleID: "schedule-1", sharedIDs: [])
        #expect(result == [ownEvent])
    }

    @Test
    func testRecordEmptyIsNoop() async throws {
        try await store.recordEvents([])
        let result = try await store.events(scheduleID: "schedule-1", sharedIDs: ["group-1"])
        #expect(result.isEmpty)
    }

    @Test
    func testDeleteByScheduleScope() async throws {
        let keep = execution(scheduleID: "schedule-2", sharedIDs: ["group-1"])
        let remove = execution(scheduleID: "schedule-1", sharedIDs: ["group-1"])
        try await store.recordEvents([keep, remove])

        try await store.deleteEvents(scopes: [.schedule("schedule-1")])

        let result = try await store.events(scheduleID: "schedule-1", sharedIDs: ["group-1"])
        #expect(result == [keep])
    }

    @Test
    func testDeleteBySharedScope() async throws {
        let removeA = execution(scheduleID: "schedule-1", sharedIDs: ["group-1"])
        let removeB = execution(scheduleID: "schedule-2", sharedIDs: ["group-1"])
        let keep = execution(scheduleID: "schedule-3")
        try await store.recordEvents([removeA, removeB, keep])

        try await store.deleteEvents(scopes: [.shared("group-1")])

        #expect(try await store.events(scheduleID: "schedule-1", sharedIDs: ["group-1"]).isEmpty)
        #expect(try await store.events(scheduleID: "schedule-2", sharedIDs: ["group-1"]).isEmpty)
        #expect(try await store.events(scheduleID: "schedule-3", sharedIDs: []) == [keep])
    }

    @Test
    func testDeleteMultipleScopes() async throws {
        let removeA = execution(scheduleID: "schedule-1")
        let removeB = execution(scheduleID: "schedule-2", sharedIDs: ["group-1"])
        let keep = execution(scheduleID: "schedule-3")
        try await store.recordEvents([removeA, removeB, keep])

        try await store.deleteEvents(
            scopes: [.schedule("schedule-1"), .shared("group-1")]
        )

        #expect(try await store.events(scheduleID: "schedule-1", sharedIDs: []).isEmpty)
        #expect(try await store.events(scheduleID: "schedule-2", sharedIDs: ["group-1"]).isEmpty)
        #expect(try await store.events(scheduleID: "schedule-3", sharedIDs: []) == [keep])
    }

    @Test
    func testDeleteEmptyScopesIsNoop() async throws {
        let event = execution(scheduleID: "schedule-1")
        try await store.recordEvents([event])

        try await store.deleteEvents(scopes: [])

        #expect(try await store.events(scheduleID: "schedule-1", sharedIDs: []) == [event])
    }

    @Test
    func testPersistsAllFields() async throws {
        let triggeredEvent = triggered(
            scheduleID: "schedule-1",
            sharedIDs: ["group-1"],
            triggerID: "trigger-1",
            variantAudienceID: "iteration-1",
            timestamp: Date(timeIntervalSince1970: 123),
            count: 3
        )
        let executionEvent = execution(
            scheduleID: "schedule-1",
            sharedIDs: ["group-1"],
            triggerID: "trigger-2",
            variantAudienceID: "iteration-2",
            timestamp: Date(timeIntervalSince1970: 456),
            count: 5,
            result: .audienceMiss,
            cancel: true
        )

        try await store.recordEvents([triggeredEvent, executionEvent])

        let result = try await store.events(scheduleID: "schedule-1", sharedIDs: ["group-1"])
        #expect(Set(result) == Set([triggeredEvent, executionEvent]))
        #expect(Set(result.compactMap(\.variantAudienceID)) == ["iteration-1", "iteration-2"])
    }

    @Test
    func testVariantAudienceIDIsNotAScope() async throws {
        try await store.recordEvents([execution(scheduleID: "schedule-1", variantAudienceID: "iteration-1")])

        #expect(try await store.events(scheduleID: "other", sharedIDs: ["iteration-1"]).isEmpty)
        #expect(try await store.sharedIDRowCount() == 0)
    }

    @Test
    func testEventsRecordedWithoutVariantAudienceIDDecodeNil() throws {
        let json = #"""
        {"type": "execution", "schedule_id": "s", "result": "succeeded", "timestamp": 0}
        """#
        let event = try JSONDecoder().decode(LedgerEvent.self, from: Data(json.utf8))
        #expect(event.variantAudienceID == nil)

        let triggeredJSON = #"{"type": "triggered", "schedule_id": "s", "timestamp": 0}"#
        let triggeredEvent = try JSONDecoder().decode(LedgerEvent.self, from: Data(triggeredJSON.utf8))
        #expect(triggeredEvent.variantAudienceID == nil)
    }

    @Test
    func testVariantAudienceIDEncodesAsSnakeCaseKey() throws {
        let data = try JSONEncoder().encode(execution(scheduleID: "s", variantAudienceID: "iteration-1"))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["variant_audience_id"] as? String == "iteration-1")

        let bare = try JSONEncoder().encode(execution(scheduleID: "s"))
        let bareObject = try #require(JSONSerialization.jsonObject(with: bare) as? [String: Any])
        #expect(bareObject["variant_audience_id"] == nil)
    }

    @Test
    func testEventCodableRoundTrip() throws {
        let events: [LedgerEvent] = [
            triggered(scheduleID: "s", sharedIDs: ["g"], triggerID: "t", variantAudienceID: "v", count: 2),
            execution(scheduleID: "s", result: .backfill, cancel: false)
        ]

        for event in events {
            let data = try JSONEncoder().encode(event)
            let decoded = try JSONDecoder().decode(LedgerEvent.self, from: data)
            #expect(decoded == event)
        }
    }

    // MARK: - Multiple shared groups

    @Test
    func testQueryFindsEventByAnyOfItsGroups() async throws {
        // Recorded while the schedule belonged to both groups.
        let event = execution(scheduleID: "schedule-1", sharedIDs: ["g1", "g2"])
        try await store.recordEvents([event])

        // A sibling in either group alone still sees it.
        #expect(try await store.events(scheduleID: "sibling", sharedIDs: ["g1"]) == [event])
        #expect(try await store.events(scheduleID: "sibling", sharedIDs: ["g2"]) == [event])
        #expect(try await store.events(scheduleID: "sibling", sharedIDs: ["g3"]).isEmpty)
    }

    /// The shared-group half of the query resolves matching rows first and
    /// leaves the clause out entirely when none match. The schedule's own
    /// events must still come back in that case.
    @Test
    func testQueryFallsBackToScheduleWhenNoGroupMatches() async throws {
        let own = execution(scheduleID: "schedule-1")
        try await store.recordEvents([own, execution(scheduleID: "other", sharedIDs: ["g1"])])

        let result = try await store.events(scheduleID: "schedule-1", sharedIDs: ["no-such-group"])
        #expect(result == [own])
    }

    @Test
    func testQueryMatchingSeveralWaysReturnsTheEventOnce() async throws {
        // Matches on its own schedule ID and on both groups at once. The row must
        // not be counted more than once, or a pooled limit would over-count and
        // suppress messages that are still within budget.
        let event = execution(scheduleID: "schedule-1", sharedIDs: ["g1", "g2"])
        try await store.recordEvents([event])

        let result = try await store.events(scheduleID: "schedule-1", sharedIDs: ["g1", "g2"])
        #expect(result == [event])
    }

    @Test
    func testCombiningTwoExistingGroupsPoolsBothHistories() async throws {
        // A and B each already pool with a partner under their own group; the two
        // are then combined under `shared` without either leaving its original.
        let aPartner = execution(scheduleID: "a-partner", sharedIDs: ["group-a"])
        let bPartner = execution(scheduleID: "b-partner", sharedIDs: ["group-b"])
        try await store.recordEvents([aPartner, bPartner])

        let forA = try await store.events(scheduleID: "a", sharedIDs: ["group-a", "shared"])
        #expect(forA == [aPartner])

        let forB = try await store.events(scheduleID: "b", sharedIDs: ["group-b", "shared"])
        #expect(forB == [bPartner])
    }

    @Test
    func testDeleteBySharedScopeRemovesEventInSeveralGroups() async throws {
        let event = execution(scheduleID: "schedule-1", sharedIDs: ["g1", "g2"])
        try await store.recordEvents([event])

        // Deleting one of its groups takes the whole event, not just that scope.
        try await store.deleteEvents(scopes: [.shared("g2")])

        #expect(try await store.events(scheduleID: "schedule-1", sharedIDs: ["g1"]).isEmpty)
    }

    // MARK: - Retention

    @Test
    func testRetainKeepsLiveScheduleAndDropsOrphans() async throws {
        let liveOwn = execution(scheduleID: "live")
        let liveViaGroup = execution(scheduleID: "dead-1", sharedIDs: ["live-group"])
        let orphanWithGroup = execution(scheduleID: "dead-2", sharedIDs: ["dead-group"])
        let orphanNoGroup = execution(scheduleID: "dead-3")

        try await store.recordEvents([liveOwn, liveViaGroup, orphanWithGroup, orphanNoGroup])

        try await store.retainEvents(
            liveScheduleIDs: ["live"],
            liveSharedIDs: ["live-group"]
        )

        // Kept: own event of a live schedule, and an event pooled under a live group.
        #expect(try await store.events(scheduleID: "live", sharedIDs: []) == [liveOwn])
        #expect(
            try await store.events(scheduleID: "dead-1", sharedIDs: ["live-group"]) == [liveViaGroup]
        )
        // Dropped: fully orphaned events, including one with no shared group.
        #expect(try await store.events(scheduleID: "dead-2", sharedIDs: ["dead-group"]).isEmpty)
        #expect(try await store.events(scheduleID: "dead-3", sharedIDs: []).isEmpty)
    }

    @Test
    func testRetainWithNoLiveIDsDropsEverything() async throws {
        try await store.recordEvents([
            execution(scheduleID: "a"),
            execution(scheduleID: "b", sharedIDs: ["g"])
        ])

        try await store.retainEvents(liveScheduleIDs: [], liveSharedIDs: [])

        #expect(try await store.events(scheduleID: "a", sharedIDs: ["g"]).isEmpty)
        #expect(try await store.events(scheduleID: "b", sharedIDs: ["g"]).isEmpty)
    }

    @Test
    func testRetainKeepsEventWhileAnyOfItsGroupsIsLive() async throws {
        let event = execution(scheduleID: "dead", sharedIDs: ["dead-group", "live-group"])
        try await store.recordEvents([event])

        try await store.retainEvents(liveScheduleIDs: [], liveSharedIDs: ["live-group"])

        #expect(try await store.events(scheduleID: "dead", sharedIDs: ["live-group"]) == [event])
    }

    @Test
    func testRetainDropsEventWhenEveryGroupIsDead() async throws {
        let event = execution(scheduleID: "dead", sharedIDs: ["g1", "g2"])
        try await store.recordEvents([event])

        try await store.retainEvents(liveScheduleIDs: [], liveSharedIDs: ["other"])

        #expect(try await store.events(scheduleID: "dead", sharedIDs: ["g1", "g2"]).isEmpty)
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

        let result = try await store.events(scheduleID: "s", sharedIDs: [])
        #expect(result.count == 1)
        #expect(result.first?.count == 2)
        #expect(result.first?.timestamp == Self.date(2017, 9, 20))
    }

    @Test
    func testCompactKeepsVariantAudienceIDWhenMerging() async throws {
        let now = Self.date(2020, 1, 1)
        try await store.recordEvents([
            execution(scheduleID: "s", variantAudienceID: "iteration-1", timestamp: Self.date(2017, 3, 5)),
            execution(scheduleID: "s", variantAudienceID: "iteration-1", timestamp: Self.date(2017, 9, 20))
        ])

        try await store.compact(now: now)

        let result = try await store.events(scheduleID: "s", sharedIDs: [])
        #expect(result.count == 1)
        #expect(result.first?.count == 2)
        #expect(result.first?.variantAudienceID == "iteration-1")
    }

    @Test
    func testCompactDoesNotMergeAcrossVariantAudienceIDs() async throws {
        let now = Self.date(2020, 1, 1)
        try await store.recordEvents([
            execution(scheduleID: "s", variantAudienceID: "iteration-1", timestamp: Self.date(2017, 3, 5)),
            execution(scheduleID: "s", variantAudienceID: "iteration-2", timestamp: Self.date(2017, 9, 20)),
            execution(scheduleID: "s", variantAudienceID: nil, timestamp: Self.date(2017, 10, 1))
        ])

        try await store.compact(now: now)

        let result = try await store.events(scheduleID: "s", sharedIDs: [])
        #expect(result.count == 3)
        #expect(Set(result.map(\.variantAudienceID)) == ["iteration-1", "iteration-2", nil])
    }

    // When the ledger is under the cap and every event is younger than a year,
    // the cheap pre-check skips the decode entirely. Two recent events sharing an
    // exact timestamp would merge in the raw tier if compaction ran, so their
    // survival proves the guard short-circuited before decoding.
    @Test
    func testCompactSkipsWhenAllRecentAndUnderCap() async throws {
        // Pre-warm the once-per-process reindex check on an empty ledger, so
        // this store's actual test call below exercises the age/cap skip on
        // its own merits rather than being forced past it by that unrelated,
        // one-time check.
        try await store.compact(now: Self.date(2020, 1, 1))

        let now = Self.date(2020, 1, 1)
        let recent = Self.date(2019, 12, 25)
        try await store.recordEvents([
            execution(scheduleID: "s", timestamp: recent),
            execution(scheduleID: "s", timestamp: recent)
        ])

        try await store.compact(now: now)

        let result = try await store.events(scheduleID: "s", sharedIDs: [])
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

        let result = try await store.events(scheduleID: "s", sharedIDs: [])
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

        let recentResult = try await store.events(scheduleID: "s", sharedIDs: [])
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
        let differByVariantAudience = [
            execution(scheduleID: "s", variantAudienceID: "v1", timestamp: old),
            execution(scheduleID: "s", variantAudienceID: "v2", timestamp: older)
        ]
        let differByVariantAudiencePresence = [
            triggered(scheduleID: "s", variantAudienceID: "v1", timestamp: old),
            triggered(scheduleID: "s", variantAudienceID: nil, timestamp: older)
        ]
        let differByScope = [
            execution(scheduleID: "s1", timestamp: old),
            execution(scheduleID: "s2", timestamp: older)
        ]
        let differByType = [
            triggered(scheduleID: "s", timestamp: old),
            execution(scheduleID: "s", timestamp: older)
        ]

        let all = [
            differByResult, differByCancel, differByTrigger, differByVariantAudience,
            differByVariantAudiencePresence, differByScope, differByType
        ]
        for events in all {
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


/// Covers the SQLite store specifically. The in-memory store deletes through the
/// object graph, which applies the relationship's cascade rule for free; on disk
/// the same deletes go through `NSBatchDeleteRequest`, which bypasses the object
/// graph. Shared-ID rows are only reachable through their event, so a delete that
/// strands them leaks rows no query would ever surface.
///
/// A class, not a struct: Swift Testing gives each test method a fresh
/// instance, so `deinit` is a natural per-test cleanup hook — every
/// `makeStore()` call leaves a real SQLite file (and its `-wal`/`-shm`
/// siblings) under `Library/`, and this removes them rather than letting them
/// accumulate across test runs. Matches the pattern from #4006.
final class LedgerStoreOnDiskTest {

    private var createdAppKeys: [String] = []

    deinit {
        removeLedgerStoreFiles(appKeys: createdAppKeys)
    }

    private func makeStore() -> LedgerStore {
        let appKey = UUID().uuidString
        createdAppKeys.append(appKey)
        return LedgerStore(appKey: appKey, inMemory: false)
    }

    private func execution(scheduleID: String, sharedIDs: [String]) -> LedgerEvent {
        return .execution(
            .init(
                scheduleID: scheduleID,
                sharedIDs: sharedIDs.isEmpty ? nil : sharedIDs,
                triggerID: nil,
                timestamp: Date(timeIntervalSince1970: 0),
                count: nil,
                result: .succeeded,
                cancel: nil
            )
        )
    }

    @Test
    func testQueryFindsEventByAnyOfItsGroups() async throws {
        let store = makeStore()
        let event = execution(scheduleID: "schedule-1", sharedIDs: ["g1", "g2"])
        try await store.recordEvents([event])

        #expect(try await store.events(scheduleID: "sibling", sharedIDs: ["g2"]) == [event])
        #expect(
            try await store.events(scheduleID: "schedule-1", sharedIDs: ["g1", "g2"]) == [event]
        )
    }

    /// A shared-group lookup must resolve against unsaved work in the same
    /// context. Every entry point saves before returning today, so nothing
    /// reaches this state in production — but the cheap way to write the
    /// lookup (a `dictionaryResultType` fetch for just the `event` column) is
    /// resolved against the store alone and would silently stop seeing a
    /// caller's own just-recorded events.
    @Test
    func testSharedGroupLookupSeesUnsavedWorkInTheSameContext() async throws {
        let store = makeStore()

        // Querying under a DIFFERENT schedule ID than the one recording, so
        // only the shared-group half of the OR can possibly match — the
        // schedule-ID half is a plain object fetch that has never been in
        // doubt, and matching through it here would hide a regression in the
        // half this test exists to cover.
        let found = try await store.eventsBeforeSaving(
            recording: execution(scheduleID: "recorder", sharedIDs: ["g"]),
            scheduleID: "sibling",
            sharedIDs: ["g"]
        )
        #expect(found == 1)
    }

    @Test
    func testVariantAudienceIDSurvivesReopeningTheStore() async throws {
        let appKey = UUID().uuidString
        createdAppKeys.append(appKey)

        let event: LedgerEvent = .execution(
            .init(
                scheduleID: "schedule-1",
                sharedIDs: nil,
                triggerID: nil,
                variantAudienceID: "iteration-1",
                timestamp: Date(timeIntervalSince1970: 0),
                count: nil,
                result: .variantMiss,
                cancel: nil
            )
        )
        try await LedgerStore(appKey: appKey, inMemory: false).recordEvents([event])

        let reopened = LedgerStore(appKey: appKey, inMemory: false)
        #expect(try await reopened.events(scheduleID: "schedule-1", sharedIDs: []) == [event])
    }

    @Test
    func testDeleteByScopeLeavesNoStrandedSharedIDRows() async throws {
        let store = makeStore()
        try await store.recordEvents([
            execution(scheduleID: "schedule-1", sharedIDs: ["g1", "g2"]),
            execution(scheduleID: "schedule-2", sharedIDs: ["g1"])
        ])
        #expect(try await store.sharedIDRowCount() == 3)

        try await store.deleteEvents(scopes: [.shared("g1")])

        #expect(try await store.events(scheduleID: "schedule-1", sharedIDs: ["g2"]).isEmpty)
        #expect(try await store.sharedIDRowCount() == 0)
    }

    @Test
    func testRetentionLeavesNoStrandedSharedIDRows() async throws {
        let store = makeStore()
        try await store.recordEvents([
            execution(scheduleID: "live", sharedIDs: ["live-group"]),
            execution(scheduleID: "dead", sharedIDs: ["dead-group", "other-dead"])
        ])
        #expect(try await store.sharedIDRowCount() == 3)

        try await store.retainEvents(
            liveScheduleIDs: ["live"],
            liveSharedIDs: ["live-group"]
        )

        #expect(try await store.events(scheduleID: "dead", sharedIDs: ["dead-group"]).isEmpty)
        // Only the surviving event's single row is left.
        #expect(try await store.sharedIDRowCount() == 1)
    }

    /// The v1 predicate carried an explicit `sharedID == nil` clause to keep
    /// group-less rows from evaluating to SQL NULL under batch delete. The
    /// SUBQUERY form that replaced it has to hold the same line, and only the
    /// on-disk path can show it — in memory these deletes go through the object
    /// graph, where NULL semantics never come up.
    @Test
    func testRetentionHandlesGroupLessRows() async throws {
        let store = makeStore()
        try await store.recordEvents([
            execution(scheduleID: "live-no-group", sharedIDs: []),
            execution(scheduleID: "dead-no-group", sharedIDs: []),
            execution(scheduleID: "dead-with-group", sharedIDs: ["dead-group"]),
            execution(scheduleID: "dead-live-group", sharedIDs: ["live-group"])
        ])

        try await store.retainEvents(
            liveScheduleIDs: ["live-no-group"],
            liveSharedIDs: ["live-group"]
        )

        #expect(try await store.events(scheduleID: "live-no-group", sharedIDs: []).count == 1)
        #expect(try await store.events(scheduleID: "dead-live-group", sharedIDs: []).count == 1)
        #expect(try await store.events(scheduleID: "dead-no-group", sharedIDs: []).isEmpty)
        #expect(try await store.events(scheduleID: "dead-with-group", sharedIDs: []).isEmpty)
        #expect(try await store.sharedIDRowCount() == 1)
    }

    @Test
    func testRetentionWithNoLiveGroupsKeepsGroupLessLiveSchedule() async throws {
        let store = makeStore()
        try await store.recordEvents([
            execution(scheduleID: "keep", sharedIDs: []),
            execution(scheduleID: "drop", sharedIDs: ["g"])
        ])

        // Empty `liveSharedIDs` makes the subquery's `IN` set empty.
        try await store.retainEvents(liveScheduleIDs: ["keep"], liveSharedIDs: [])

        #expect(try await store.events(scheduleID: "keep", sharedIDs: []).count == 1)
        #expect(try await store.events(scheduleID: "drop", sharedIDs: []).isEmpty)
        #expect(try await store.sharedIDRowCount() == 0)
    }

    @Test
    func testRetentionKeepsEventWhileAnyGroupIsLive() async throws {
        let store = makeStore()
        let event = execution(scheduleID: "dead", sharedIDs: ["dead-group", "live-group"])
        try await store.recordEvents([event])

        try await store.retainEvents(liveScheduleIDs: [], liveSharedIDs: ["live-group"])

        #expect(try await store.events(scheduleID: "dead", sharedIDs: ["live-group"]) == [event])
        #expect(try await store.sharedIDRowCount() == 2)
    }

    @Test
    func testCompactionRewritesSharedIDRowsRatherThanDuplicatingThem() async throws {
        let store = makeStore()
        let old = Date(timeIntervalSince1970: 0)
        let now = old.addingTimeInterval(LedgerCompactor.rawMaxAge * 3)

        // Two mergeable events in the same pair of groups, old enough to bucket.
        try await store.recordEvents([
            execution(scheduleID: "s", sharedIDs: ["g1", "g2"]),
            execution(scheduleID: "s", sharedIDs: ["g1", "g2"])
        ])
        #expect(try await store.sharedIDRowCount() == 4)

        try await store.compact(now: now)

        let result = try await store.events(scheduleID: "s", sharedIDs: [])
        #expect(result.count == 1)
        #expect(result.first?.count == 2)
        #expect(result.first?.sharedIDs == ["g1", "g2"])
        // One event left, so two rows — not four, and not zero.
        #expect(try await store.sharedIDRowCount() == 2)
    }

    /// `insertEvent` canonicalizes rather than trusting its caller, so a
    /// payload carrying the same group twice writes one row, not two.
    @Test
    func testRecordEventsCanonicalizesDuplicateSharedIDs() async throws {
        let store = makeStore()
        try await store.recordEvents([
            execution(scheduleID: "s", sharedIDs: ["g1", "g1", "g1"])
        ])

        #expect(try await store.sharedIDRowCount() == 1)
        let result = try await store.events(scheduleID: "s", sharedIDs: [])
        #expect(result.first?.sharedIDs == ["g1"])
    }

    /// A compaction rewrite goes through the same `insertEvent` as direct
    /// recording, so it canonicalizes too — the merged event this produces
    /// does not carry forward a duplicate from whichever input event happened
    /// to be picked as the merge's representative.
    @Test
    func testCompactionRewriteCanonicalizesSharedIDs() async throws {
        let store = makeStore()
        let old = Date(timeIntervalSince1970: 0)
        let now = old.addingTimeInterval(LedgerCompactor.rawMaxAge * 3)

        try await store.recordEvents([
            execution(scheduleID: "s", sharedIDs: ["g1", "g1"]),
            execution(scheduleID: "s", sharedIDs: ["g1", "g1"])
        ])

        try await store.compact(now: now)

        let result = try await store.events(scheduleID: "s", sharedIDs: [])
        #expect(result.count == 1)
        #expect(result.first?.sharedIDs == ["g1"])
        #expect(try await store.sharedIDRowCount() == 1)
    }
}


/// Upgrade path from the shipped single-`sharedID` model (21.0.0-beta.2/.3) to
/// the multi-group one. A device that already has a v1 ledger on disk must come
/// up on v2 without throwing, and without silently dropping the history it can
/// still account for.
///
/// A class, not a struct, so `deinit` can clean up the real SQLite files each
/// test seeds directly through Core Data — see ``LedgerStoreOnDiskTest``.
final class LedgerStoreMigrationTest {

    private var createdAppKeys: [String] = []

    deinit {
        removeLedgerStoreFiles(appKeys: createdAppKeys)
    }

    private func execution(scheduleID: String, sharedIDs: [String], timestamp: Date) -> LedgerEvent {
        .execution(
            .init(
                scheduleID: scheduleID,
                sharedIDs: sharedIDs.isEmpty ? nil : sharedIDs,
                triggerID: nil,
                timestamp: timestamp,
                count: nil,
                result: .succeeded,
                cancel: nil
            )
        )
    }

    /// Where `UACoreData` puts its SQLite files.
    private func storeURL(appKey: String) throws -> URL {
        createdAppKeys.append(appKey)
        let directory = try #require(
            FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).last
        ).appendingPathComponent("com.urbanairship.no-backup")

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory.appendingPathComponent("AirshipLedger-\(appKey).sqlite")
    }

    /// Writes one event through the *old* model, so the store on disk is a
    /// genuine v1 file rather than a v2 file with a field left empty.
    ///
    /// The `body` blob is a literal old-key JSON string rather than something
    /// built by encoding a `LedgerEvent` — the current encoder only ever
    /// writes `shared_ids`, so encoding it here would silently produce a
    /// v2-shaped body sitting inside a v1 SQL row, which is not what a real
    /// beta.2/.3 device has on disk and would hide a decode-time regression on
    /// the legacy `shared_id` key instead of catching it.
    private func seedV1Store(
        appKey: String,
        scheduleID: String,
        sharedID: String?,
        type: String = "execution"
    ) throws {
        let momd = try #require(
            AirshipAutomationResources.bundle.url(
                forResource: "AirshipLedger",
                withExtension: "momd"
            )
        )
        let v1URL = momd.appendingPathComponent("AirshipLedger.mom")
        let v1Model = try #require(NSManagedObjectModel(contentsOf: v1URL))
        // Guard against the fixture drifting into the new shape: v1 is exactly
        // the model that has no shared-ID entity.
        #expect(v1Model.entitiesByName["UALedgerSharedIDData"] == nil)

        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: v1Model)
        try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: try storeURL(appKey: appKey),
            options: nil
        )

        let sharedIDField = sharedID.map { "\"shared_id\": \"\($0)\"," } ?? ""
        let resultField = type == "execution" ? "\"result\": \"succeeded\"," : ""
        let body = """
        {
          "type": "\(type)",
          "schedule_id": "\(scheduleID)",
          \(sharedIDField)
          \(resultField)
          "timestamp": 0
        }
        """

        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator

        var thrown: (any Error)?
        context.performAndWait {
            do {
                let entity = try #require(
                    NSEntityDescription.insertNewObject(
                        forEntityName: "UALedgerEventData",
                        into: context
                    ) as NSManagedObject?
                )
                entity.setValue(scheduleID, forKey: "scheduleID")
                entity.setValue(sharedID, forKey: "sharedID")
                entity.setValue(Date(timeIntervalSince1970: 0), forKey: "timestamp")
                entity.setValue(Data(body.utf8), forKey: "body")
                try context.save()
            } catch {
                thrown = error
            }
        }
        if let thrown { throw thrown }

        for store in coordinator.persistentStores {
            try coordinator.remove(store)
        }
    }

    @Test
    func testOpensAV1StoreAndKeepsPerScheduleHistory() async throws {
        let appKey = UUID().uuidString
        try seedV1Store(appKey: appKey, scheduleID: "schedule-1", sharedID: "group-1")

        let store = LedgerStore(appKey: appKey, inMemory: false)

        // The event survives under its own schedule ID, and the body blob's
        // legacy `shared_id` key decodes correctly via the fallback — the
        // group isn't lost, it's just not the thing that changed here.
        let result = try await store.events(scheduleID: "schedule-1", sharedIDs: [])
        #expect(result.count == 1)
        #expect(result.first?.sharedIDs == ["group-1"])
        // A stored body with no `variant_audience_id` key decodes to nil.
        #expect(result.first?.variantAudienceID == nil)

        // What migration does NOT restore is the *index*: `sharedID` is a
        // scalar SQL column with no lightweight mapping onto the v2 to-many
        // relationship, so this event has no `UALedgerSharedIDData` rows yet.
        // A schedule-ID query decodes the body and sees the group (above); a
        // group-only query never decodes this body at all — it's answered
        // entirely from the (currently empty) index — so a sibling can't find
        // it purely by group until something re-indexes it.
        #expect(try await store.events(scheduleID: "sibling", sharedIDs: ["group-1"]).isEmpty)

        // That something is the next compaction pass, which decodes every
        // body, canonicalizes, and rewrites — see
        // ``testCompactionAfterMigrationRebuildsSharedIDRows``, which covers
        // the far side of this same event.

        // And the store is writable on the new model afterwards.
        try await store.recordEvents([
            .execution(
                .init(
                    scheduleID: "schedule-2",
                    sharedIDs: ["group-1"],
                    triggerID: nil,
                    timestamp: Date(timeIntervalSince1970: 1),
                    count: nil,
                    result: .succeeded,
                    cancel: nil
                )
            )
        ])
        // Only the freshly recorded event is indexed under the group so far.
        #expect(try await store.events(scheduleID: "other", sharedIDs: ["group-1"]).count == 1)
    }

    /// `triggered` events decode their own copy of the legacy `shared_id` key,
    /// separate from `execution`'s, so the fallback needs its own coverage.
    @Test
    func testLegacySharedIDDecodesOnATriggeredEvent() async throws {
        let appKey = UUID().uuidString
        try seedV1Store(appKey: appKey, scheduleID: "schedule-1", sharedID: "group-1", type: "triggered")

        let store = LedgerStore(appKey: appKey, inMemory: false)

        let result = try await store.events(scheduleID: "schedule-1", sharedIDs: [])
        #expect(result.count == 1)
        guard case .triggered = result.first else {
            Issue.record("Expected a triggered event")
            return
        }
        #expect(result.first?.sharedIDs == ["group-1"])

        try await store.compact(now: Date(timeIntervalSince1970: 1))
        #expect(try await store.sharedIDRowCount() == 1)
        #expect(try await store.events(scheduleID: "sibling", sharedIDs: ["group-1"]).count == 1)
    }

    @Test
    func testOpensAV1StoreWithNoSharedGroup() async throws {
        let appKey = UUID().uuidString
        try seedV1Store(appKey: appKey, scheduleID: "schedule-1", sharedID: nil)

        let store = LedgerStore(appKey: appKey, inMemory: false)
        #expect(try await store.events(scheduleID: "schedule-1", sharedIDs: []).count == 1)
    }

    /// A migrated event's group is only recoverable from its `body` blob until
    /// something rewrites that blob. Compaction is exactly such a rewrite — it
    /// decodes, re-encodes, and replaces every event it touches — so this pins
    /// that the recovered group survives the round trip rather than being
    /// dropped again on the first pass that isn't a plain read.
    @Test
    func testCompactionAfterMigrationRebuildsSharedIDRows() async throws {
        let appKey = UUID().uuidString
        try seedV1Store(appKey: appKey, scheduleID: "schedule-1", sharedID: "group-1")

        let store = LedgerStore(appKey: appKey, inMemory: false)
        // Old enough to be merge-eligible, forcing compaction to rewrite it
        // rather than skip it as already-current.
        try await store.compact(
            now: Date(timeIntervalSince1970: 0).addingTimeInterval(LedgerCompactor.rawMaxAge * 3)
        )

        let result = try await store.events(scheduleID: "schedule-1", sharedIDs: [])
        #expect(result.count == 1)
        #expect(result.first?.sharedIDs == ["group-1"])

        // Rebuilt as an indexed row, not just present in the re-encoded body.
        #expect(try await store.events(scheduleID: "sibling", sharedIDs: ["group-1"]).count == 1)
    }

    /// Same as ``testCompactionAfterMigrationRebuildsSharedIDRows``, but with
    /// a realistic `now` (a moment after the seeded event, not three years
    /// after it) instead of one contrived to force past the age/cap skip.
    /// This is the actual shape of the first `compact` call on a real,
    /// just-upgraded device — the once-per-process reindex check has to force
    /// the pass on its own, not ride along on an unrelated age trigger.
    @Test
    func testCompactionReindexesOnFirstCallEvenWithARealisticNow() async throws {
        let appKey = UUID().uuidString
        try seedV1Store(appKey: appKey, scheduleID: "schedule-1", sharedID: "group-1")

        let store = LedgerStore(appKey: appKey, inMemory: false)
        try await store.compact(now: Date(timeIntervalSince1970: 1))

        #expect(try await store.sharedIDRowCount() == 1)
        #expect(try await store.events(scheduleID: "sibling", sharedIDs: ["group-1"]).count == 1)
    }

    /// The once-per-process reindex pass really is once: a second `compact`
    /// call on an already-verified store must not force the full decode
    /// again. Two recent same-timestamp events would merge if it did; their
    /// survival on this second call proves the age/cap skip took over.
    @Test
    func testCompactionOnlyForcesTheReindexPassOnce() async throws {
        let store = LedgerStore(appKey: UUID().uuidString, inMemory: false)
        let now = Date(timeIntervalSince1970: 1)

        // First call: forces the pass (nothing to reindex, but consumes it).
        try await store.compact(now: now)

        try await store.recordEvents([
            execution(scheduleID: "s", sharedIDs: [], timestamp: now),
            execution(scheduleID: "s", sharedIDs: [], timestamp: now)
        ])

        // Second call: should now respect the ordinary age/cap skip.
        try await store.compact(now: now)

        let result = try await store.events(scheduleID: "s", sharedIDs: [])
        #expect(result.count == 2)
    }

    /// Ulrico972's report: `retainEvents`'s liveness check reads only the
    /// shared-group index, which is empty for a migrated event until
    /// reindexed. Calling it before `compact` (the bug) deletes a still-live
    /// group's history; calling `compact` first (the fix, and the order
    /// `AutomationStore.reconcileLedger` now uses) rebuilds the index in time
    /// for `retainEvents` to see the group is still live.
    @Test
    func testCompactingBeforeRetainingPreservesAMigratedEventsLiveGroup() async throws {
        let appKey = UUID().uuidString
        try seedV1Store(appKey: appKey, scheduleID: "schedule-1", sharedID: "group-1")

        let store = LedgerStore(appKey: appKey, inMemory: false)

        // schedule-1 itself is retiring; a sibling still shares group-1.
        try await store.compact(now: Date(timeIntervalSince1970: 1))
        try await store.retainEvents(liveScheduleIDs: [], liveSharedIDs: ["group-1"])

        #expect(try await store.events(scheduleID: "schedule-1", sharedIDs: []).count == 1)
    }

    /// The failure mode the fix above prevents, pinned directly: calling
    /// `retainEvents` before any `compact` call deletes the migrated event
    /// even though its group is live, because the index it reads is still
    /// empty. Not the order production uses — this documents why the order
    /// matters, rather than trusting the comment alone.
    @Test
    func testRetainingBeforeCompactingLosesAMigratedEventsLiveGroup() async throws {
        let appKey = UUID().uuidString
        try seedV1Store(appKey: appKey, scheduleID: "schedule-1", sharedID: "group-1")

        let store = LedgerStore(appKey: appKey, inMemory: false)

        try await store.retainEvents(liveScheduleIDs: [], liveSharedIDs: ["group-1"])

        #expect(try await store.events(scheduleID: "schedule-1", sharedIDs: []).isEmpty)
    }
}
