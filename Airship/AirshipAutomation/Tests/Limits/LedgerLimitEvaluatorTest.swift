/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable @_spi(AirshipInternal) import AirshipAutomation
@_spi(AirshipInternal) import AirshipCore

struct LedgerLimitEvaluatorTest {

    private let store: LedgerStore
    private let date = UATestDate(offset: 0, dateOverride: Date(timeIntervalSince1970: 10_000))
    private let evaluator: LedgerLimitEvaluator

    init() {
        self.store = LedgerStore(appKey: UUID().uuidString, inMemory: true)
        self.evaluator = LedgerLimitEvaluator(store: self.store, date: self.date)
    }

    private func schedule(
        id: String = "schedule-A",
        limit: UInt?,
        sharedID: String? = nil,
        limitConfig: LimitConfig? = nil
    ) -> AutomationSchedule {
        return AutomationSchedule(
            identifier: id,
            data: .actions(.string("actions")),
            triggers: [],
            limit: limit,
            ledgerConfig: sharedID.map { AutomationSchedule.LedgerConfig(sharedID: $0) },
            limitConfig: limitConfig
        )
    }

    private func recordExecution(
        scheduleID: String = "schedule-A",
        sharedID: String? = nil,
        result: LedgerExecutionResult = .succeeded,
        count: Int? = nil
    ) async throws {
        try await self.store.recordEvents([
            .execution(
                LedgerEvent.Execution(
                    scheduleID: scheduleID,
                    sharedID: sharedID,
                    triggerID: nil,
                    timestamp: self.date.now,
                    count: count,
                    result: result,
                    cancel: nil
                )
            )
        ])
    }

    @Test
    func testUnderLimit() async throws {
        try await recordExecution()
        let over = await evaluator.isOverLimit(schedule: schedule(limit: 2))
        #expect(!over)
    }

    @Test
    func testAtLimit() async throws {
        try await recordExecution()
        try await recordExecution()
        let over = await evaluator.isOverLimit(schedule: schedule(limit: 2))
        #expect(over)
    }

    @Test
    func testNilLimitDefaultsToOne() async throws {
        try await recordExecution()
        let over = await evaluator.isOverLimit(schedule: schedule(limit: nil))
        #expect(over)
    }

    @Test
    func testZeroLimitIsUnlimited() async throws {
        for _ in 0..<50 {
            try await recordExecution()
        }
        let over = await evaluator.isOverLimit(schedule: schedule(limit: 0))
        #expect(!over)
    }

    @Test
    func testCountsAcrossSharedGroup() async throws {
        // Two different schedules recording under the same shared group pool.
        try await recordExecution(scheduleID: "schedule-A", sharedID: "group-1")
        try await recordExecution(scheduleID: "schedule-B", sharedID: "group-1")

        let over = await evaluator.isOverLimit(
            schedule: schedule(
                id: "schedule-A", limit: 2, sharedID: "group-1",
                limitConfig: .shared(exclude: nil)
            )
        )
        #expect(over)
    }

    @Test
    func testSharedEventsIgnoredWithoutSharedLimitConfig() async throws {
        // Same setup as testCountsAcrossSharedGroup, but this schedule never
        // opted in — its own payload alone must determine its tally, so
        // schedule-B's contribution must not count, no matter what schedule-B
        // itself declares. No limit_config at all defaults to .selfOnly.
        try await recordExecution(scheduleID: "schedule-A", sharedID: "group-1")
        try await recordExecution(scheduleID: "schedule-B", sharedID: "group-1")

        let over = await evaluator.isOverLimit(
            schedule: schedule(id: "schedule-A", limit: 2, sharedID: "group-1")
        )
        #expect(!over)
    }

    @Test
    func testExplicitSelfOnlyIgnoresSharedGroup() async throws {
        // An explicit .selfOnly behaves the same as no limit_config at all.
        try await recordExecution(scheduleID: "schedule-A", sharedID: "group-1")
        try await recordExecution(scheduleID: "schedule-B", sharedID: "group-1")

        let over = await evaluator.isOverLimit(
            schedule: schedule(
                id: "schedule-A", limit: 2, sharedID: "group-1",
                limitConfig: .selfOnly(exclude: nil)
            )
        )
        #expect(!over)
    }

    @Test
    func testSharedInheritsNamedSchedulesBareHistory() async throws {
        // schedule-original has pre-existing history recorded before it was
        // ever part of a group (e.g. backfilled pre-ledger executions) — no
        // sharedID on the event at all, just its own scheduleID.
        try await recordExecution(scheduleID: "schedule-original", result: .backfill, count: 3)

        // schedule-new joins by naming schedule-original's own ID as its
        // shared_id, and opts into counting it.
        let over = await evaluator.isOverLimit(
            schedule: schedule(
                id: "schedule-new", limit: 3, sharedID: "schedule-original",
                limitConfig: .shared(exclude: nil)
            )
        )
        #expect(over)
    }

    @Test
    func testEventsOutsideScopeIgnored() async throws {
        // An event for an unrelated schedule/group must not count.
        try await recordExecution(scheduleID: "schedule-Z", sharedID: "other-group")

        let over = await evaluator.isOverLimit(
            schedule: schedule(
                id: "schedule-A", limit: 1, sharedID: "group-1",
                limitConfig: .shared(exclude: nil)
            )
        )
        #expect(!over)
    }

    @Test
    func testLimitConfigExcludesOtherSchedules() async throws {
        try await recordExecution(scheduleID: "schedule-A", sharedID: "group-1")
        try await recordExecution(scheduleID: "schedule-B", sharedID: "group-1")

        let config = LimitConfig.shared(
            exclude: ExclusionSet(or: [ExclusionRule(source: .otherSchedules, match: nil)])
        )

        // schedule-B's event is excluded, leaving only schedule-A's one event.
        let overAt1 = await evaluator.isOverLimit(
            schedule: schedule(id: "schedule-A", limit: 1, sharedID: "group-1", limitConfig: config)
        )
        #expect(overAt1)

        let overAt2 = await evaluator.isOverLimit(
            schedule: schedule(id: "schedule-A", limit: 2, sharedID: "group-1", limitConfig: config)
        )
        #expect(!overAt2)
    }

    @Test
    func testSelfOnlyExcludesOwnEvents() async throws {
        // .selfOnly's exclude rules have no `source` — they always apply to
        // this schedule's own events, the only thing in scope.
        try await recordExecution(scheduleID: "schedule-A", result: .variantMiss)
        try await recordExecution(scheduleID: "schedule-A", result: .succeeded)

        let config = LimitConfig.selfOnly(
            exclude: SelfExclusionSet(
                or: [SelfExclusionRule(match: .execution(.init(results: [.variantMiss])))]
            )
        )

        // The variantMiss event is excluded, leaving only the succeeded one.
        let overAt1 = await evaluator.isOverLimit(
            schedule: schedule(id: "schedule-A", limit: 1, limitConfig: config)
        )
        #expect(overAt1)

        let overAt2 = await evaluator.isOverLimit(
            schedule: schedule(id: "schedule-A", limit: 2, limitConfig: config)
        )
        #expect(!overAt2)
    }

    @Test
    func testBackfillCountContributes() async throws {
        try await recordExecution(result: .backfill, count: 4)
        #expect(await evaluator.isOverLimit(schedule: schedule(limit: 4)))
        #expect(!(await evaluator.isOverLimit(schedule: schedule(limit: 5))))
    }

    // MARK: - Schedule parsing

    @Test
    func testScheduleDecodesSharedLimitConfig() throws {
        let json = """
        {
          "id": "test-schedule",
          "type": "actions",
          "actions": { "foo": "bar" },
          "triggers": [],
          "limit": 3,
          "ledger_config": { "shared_id": "group-1" },
          "limit_config": {
            "type": "shared",
            "exclude": {
              "or": [
                { "source": { "type": "own_schedule" }, "match": { "type": "execution", "results": ["variant_miss"] } }
              ]
            }
          }
        }
        """
        let schedule = try JSONDecoder().decode(AutomationSchedule.self, from: Data(json.utf8))

        #expect(schedule.limit == 3)
        #expect(schedule.ledgerSharedID == "group-1")

        guard case .shared(let exclude) = schedule.limitConfig else {
            Issue.record("Expected .shared limitConfig")
            return
        }
        let rule = try #require(exclude?.or.first)
        #expect(rule.source == .ownSchedule)
    }

    @Test
    func testScheduleDecodesSelfLimitConfig() throws {
        let json = """
        {
          "id": "test-schedule",
          "type": "actions",
          "actions": { "foo": "bar" },
          "triggers": [],
          "limit": 3,
          "limit_config": {
            "type": "self",
            "exclude": {
              "or": [
                { "match": { "type": "execution", "results": ["variant_miss"] } }
              ]
            }
          }
        }
        """
        let schedule = try JSONDecoder().decode(AutomationSchedule.self, from: Data(json.utf8))

        guard case .selfOnly(let exclude) = schedule.limitConfig else {
            Issue.record("Expected .selfOnly limitConfig")
            return
        }
        #expect(exclude?.or.count == 1)
    }

    @Test
    func testScheduleDecodesUnknownLimitConfigType() throws {
        // A `type` this SDK version does not recognize falls back to a safe
        // .unknown case rather than failing the whole schedule decode.
        let json = """
        {
          "id": "test-schedule",
          "type": "actions",
          "actions": { "foo": "bar" },
          "triggers": [],
          "limit_config": { "type": "some_future_type" }
        }
        """
        let schedule = try JSONDecoder().decode(AutomationSchedule.self, from: Data(json.utf8))
        #expect(schedule.limitConfig == .unknown)
    }

    @Test
    func testScheduleWithoutLimitConfigIsNil() throws {
        let json = """
        {
          "id": "test-schedule",
          "type": "actions",
          "actions": { "foo": "bar" },
          "triggers": []
        }
        """
        let schedule = try JSONDecoder().decode(AutomationSchedule.self, from: Data(json.utf8))
        #expect(schedule.limitConfig == nil)
    }
}
