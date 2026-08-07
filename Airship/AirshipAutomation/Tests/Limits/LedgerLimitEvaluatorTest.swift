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
            schedule: schedule(id: "schedule-A", limit: 2, sharedID: "group-1")
        )
        #expect(over)
    }

    @Test
    func testEventsOutsideScopeIgnored() async throws {
        // An event for an unrelated schedule/group must not count.
        try await recordExecution(scheduleID: "schedule-Z", sharedID: "other-group")

        let over = await evaluator.isOverLimit(
            schedule: schedule(id: "schedule-A", limit: 1, sharedID: "group-1")
        )
        #expect(!over)
    }

    @Test
    func testLimitConfigExcludesOtherSchedules() async throws {
        try await recordExecution(scheduleID: "schedule-A", sharedID: "group-1")
        try await recordExecution(scheduleID: "schedule-B", sharedID: "group-1")

        let config = LimitConfig(
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
    func testBackfillCountContributes() async throws {
        try await recordExecution(result: .backfill, count: 4)
        #expect(await evaluator.isOverLimit(schedule: schedule(limit: 4)))
        #expect(!(await evaluator.isOverLimit(schedule: schedule(limit: 5))))
    }

    // MARK: - Schedule parsing

    @Test
    func testScheduleDecodesLimitConfig() throws {
        let json = """
        {
          "id": "test-schedule",
          "type": "actions",
          "actions": { "foo": "bar" },
          "triggers": [],
          "limit": 3,
          "ledger_config": { "shared_id": "group-1" },
          "limit_config": {
            "exclude": {
              "or": [
                { "source": { "type": "own_schedule" }, "match": { "type": "execution", "results": ["control"] } }
              ]
            }
          }
        }
        """
        let schedule = try JSONDecoder().decode(AutomationSchedule.self, from: Data(json.utf8))

        #expect(schedule.limit == 3)
        #expect(schedule.ledgerSharedID == "group-1")

        let rule = try #require(schedule.limitConfig?.exclude?.or.first)
        #expect(rule.source == .ownSchedule)
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
