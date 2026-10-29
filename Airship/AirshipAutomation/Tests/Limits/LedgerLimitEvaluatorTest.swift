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
        sharedIDs: [String] = [],
        limitConfig: LimitConfig? = nil,
        variantAudienceID: String? = nil
    ) -> AutomationSchedule {
        let variantAudience = variantAudienceID.map { id in
            let json = """
            {
              "id": "\(id)",
              "audience_hash": {
                "hash_prefix": "prefix:",
                "num_hash_buckets": 16384,
                "hash_identifier": "contact",
                "hash_algorithm": "farm_hash"
              },
              "audience_subset": { "min_hash_bucket": 0, "max_hash_bucket": 0 }
            }
            """
            return try! JSONDecoder().decode(VariantAudience.self, from: Data(json.utf8))
        }

        return AutomationSchedule(
            identifier: id,
            data: .actions(.string("actions")),
            triggers: [],
            limit: limit,
            variantAudience: variantAudience,
            ledgerConfig: sharedIDs.isEmpty ? nil : AutomationSchedule.LedgerConfig(sharedIDs: sharedIDs),
            limitConfig: limitConfig
        )
    }

    private func recordExecution(
        scheduleID: String = "schedule-A",
        sharedIDs: [String] = [],
        result: LedgerExecutionResult = .succeeded,
        count: Int? = nil,
        variantAudienceID: String? = nil
    ) async throws {
        try await self.store.recordEvents([
            .execution(
                LedgerEvent.Execution(
                    scheduleID: scheduleID,
                    sharedIDs: sharedIDs.isEmpty ? nil : sharedIDs,
                    triggerID: nil,
                    variantAudienceID: variantAudienceID,
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
        try await recordExecution(scheduleID: "schedule-A", sharedIDs: ["group-1"])
        try await recordExecution(scheduleID: "schedule-B", sharedIDs: ["group-1"])

        let over = await evaluator.isOverLimit(
            schedule: schedule(
                id: "schedule-A", limit: 2, sharedIDs: ["group-1"],
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
        try await recordExecution(scheduleID: "schedule-A", sharedIDs: ["group-1"])
        try await recordExecution(scheduleID: "schedule-B", sharedIDs: ["group-1"])

        let over = await evaluator.isOverLimit(
            schedule: schedule(id: "schedule-A", limit: 2, sharedIDs: ["group-1"])
        )
        #expect(!over)
    }

    @Test
    func testExplicitSelfOnlyIgnoresSharedGroup() async throws {
        // An explicit .selfOnly behaves the same as no limit_config at all.
        try await recordExecution(scheduleID: "schedule-A", sharedIDs: ["group-1"])
        try await recordExecution(scheduleID: "schedule-B", sharedIDs: ["group-1"])

        let over = await evaluator.isOverLimit(
            schedule: schedule(
                id: "schedule-A", limit: 2, sharedIDs: ["group-1"],
                limitConfig: .selfOnly(exclude: nil)
            )
        )
        #expect(!over)
    }

    @Test
    func testSharedInheritsNamedSchedulesBareHistory() async throws {
        // schedule-original has pre-existing history recorded before it was
        // ever part of a group (e.g. backfilled pre-ledger executions) — no
        // sharedIDs on the event at all, just its own scheduleID.
        try await recordExecution(scheduleID: "schedule-original", result: .backfill, count: 3)

        // schedule-new joins by naming schedule-original's own ID as one of
        // its shared_ids, and opts into counting it.
        let over = await evaluator.isOverLimit(
            schedule: schedule(
                id: "schedule-new", limit: 3, sharedIDs: ["schedule-original"],
                limitConfig: .shared(exclude: nil)
            )
        )
        #expect(over)
    }

    @Test
    func testEventsOutsideScopeIgnored() async throws {
        // An event for an unrelated schedule/group must not count.
        try await recordExecution(scheduleID: "schedule-Z", sharedIDs: ["other-group"])

        let over = await evaluator.isOverLimit(
            schedule: schedule(
                id: "schedule-A", limit: 1, sharedIDs: ["group-1"],
                limitConfig: .shared(exclude: nil)
            )
        )
        #expect(!over)
    }

    @Test
    func testLimitConfigExcludesOtherSchedules() async throws {
        try await recordExecution(scheduleID: "schedule-A", sharedIDs: ["group-1"])
        try await recordExecution(scheduleID: "schedule-B", sharedIDs: ["group-1"])

        let config = LimitConfig.shared(
            exclude: ExclusionSet(or: [ExclusionRule(source: .otherSchedules, match: nil)])
        )

        // schedule-B's event is excluded, leaving only schedule-A's one event.
        let overAt1 = await evaluator.isOverLimit(
            schedule: schedule(id: "schedule-A", limit: 1, sharedIDs: ["group-1"], limitConfig: config)
        )
        #expect(overAt1)

        let overAt2 = await evaluator.isOverLimit(
            schedule: schedule(id: "schedule-A", limit: 2, sharedIDs: ["group-1"], limitConfig: config)
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

    private func excludingVariantAudience(_ match: VariantAudienceMatch) -> LimitConfig {
        .selfOnly(
            exclude: SelfExclusionSet(
                or: [SelfExclusionRule(match: .execution(.init(variantAudience: match)))]
            )
        )
    }

    @Test
    func testNotCurrentVariantAudienceDropsPastIterations() async throws {
        try await recordExecution(result: .variantMiss, variantAudienceID: "iteration-1")
        try await recordExecution(result: .variantMiss, variantAudienceID: "iteration-2")
        // Recorded before the schedule joined an experiment: never matched.
        try await recordExecution(result: .succeeded)

        let config = excludingVariantAudience(.notCurrent)

        let overAtThree = await evaluator.isOverLimit(
            schedule: schedule(limit: 3, limitConfig: config, variantAudienceID: "iteration-2")
        )
        #expect(!overAtThree)

        let overAtTwo = await evaluator.isOverLimit(
            schedule: schedule(limit: 2, limitConfig: config, variantAudienceID: "iteration-2")
        )
        #expect(overAtTwo)
    }

    @Test
    func testCurrentVariantAudienceDropsCurrentIteration() async throws {
        try await recordExecution(variantAudienceID: "iteration-1")
        try await recordExecution(variantAudienceID: "iteration-2")

        let config = excludingVariantAudience(.current)

        let overAtTwo = await evaluator.isOverLimit(
            schedule: schedule(limit: 2, limitConfig: config, variantAudienceID: "iteration-2")
        )
        #expect(!overAtTwo)

        let overAtOne = await evaluator.isOverLimit(
            schedule: schedule(limit: 1, limitConfig: config, variantAudienceID: "iteration-2")
        )
        #expect(overAtOne)
    }

    @Test
    func testCurrentVariantAudienceMatchesNothingWithoutScheduleVariantAudience() async throws {
        try await recordExecution(variantAudienceID: "iteration-1")

        let over = await evaluator.isOverLimit(
            schedule: schedule(limit: 1, limitConfig: excludingVariantAudience(.current))
        )
        #expect(over)
    }

    @Test
    func testVariantAudienceIDMatchDropsNamedIteration() async throws {
        try await recordExecution(variantAudienceID: "iteration-1")
        try await recordExecution(variantAudienceID: "iteration-2")

        let config = excludingVariantAudience(.id("iteration-1"))
        let over = await evaluator.isOverLimit(
            schedule: schedule(limit: 2, limitConfig: config, variantAudienceID: "iteration-2")
        )
        #expect(!over)
    }

    @Test
    func testBackfillCountContributes() async throws {
        try await recordExecution(result: .backfill, count: 4)
        #expect(await evaluator.isOverLimit(schedule: schedule(limit: 4)))
        #expect(!(await evaluator.isOverLimit(schedule: schedule(limit: 5))))
    }

    // MARK: - Schedule parsing

    @Test
    func testScheduleDecodesVariantAudienceMatch() throws {
        let json = """
        {
          "id": "test-schedule",
          "type": "actions",
          "actions": { "foo": "bar" },
          "triggers": [],
          "limit_config": {
            "type": "shared",
            "exclude": {
              "or": [{
                "source": { "type": "any" },
                "match": {
                  "type": "execution",
                  "results": ["holdout", "variant_miss"],
                  "variant_audience": { "type": "not_current" }
                }
              }]
            }
          }
        }
        """
        let schedule = try JSONDecoder().decode(AutomationSchedule.self, from: Data(json.utf8))

        guard case .shared(let exclude) = schedule.limitConfig,
              case .execution(let match) = exclude?.or.first?.match else {
            Issue.record("Expected a shared limitConfig with an execution match")
            return
        }
        #expect(match.variantAudience == .notCurrent)
    }

    @Test
    func testScheduleDecodesSharedLimitConfig() throws {
        let json = """
        {
          "id": "test-schedule",
          "type": "actions",
          "actions": { "foo": "bar" },
          "triggers": [],
          "limit": 3,
          "ledger_config": { "shared_ids": ["group-1"] },
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
        #expect(schedule.ledgerSharedIDs == ["group-1"])

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

    // MARK: - Multiple shared groups

    @Test
    func testCountsAcrossEveryGroupTheScheduleBelongsTo() async throws {
        try await recordExecution(scheduleID: "schedule-B", sharedIDs: ["group-1"])
        try await recordExecution(scheduleID: "schedule-C", sharedIDs: ["group-2"])

        // One event from each pool, against a cap of 2.
        #expect(
            await evaluator.isOverLimit(
                schedule: schedule(
                    limit: 2, sharedIDs: ["group-1", "group-2"],
                    limitConfig: .shared(exclude: nil)
                )
            )
        )
        #expect(
            !(await evaluator.isOverLimit(
                schedule: schedule(
                    limit: 3, sharedIDs: ["group-1", "group-2"],
                    limitConfig: .shared(exclude: nil)
                )
            ))
        )
    }

    @Test
    func testGroupTheScheduleHasLeftDoesNotCount() async throws {
        try await recordExecution(scheduleID: "schedule-B", sharedIDs: ["group-2"])

        // Only in group-1 now, so group-2's history is out of scope.
        #expect(
            !(await evaluator.isOverLimit(
                schedule: schedule(limit: 1, sharedIDs: ["group-1"], limitConfig: .shared(exclude: nil))
            ))
        )
    }

    @Test
    func testEventInSeveralGroupsCountsOnce() async throws {
        // Recorded by a sibling that was in both pools. The evaluating schedule is
        // in both too, so the event matches twice over — it must still count once.
        try await recordExecution(scheduleID: "schedule-B", sharedIDs: ["group-1", "group-2"])

        #expect(
            !(await evaluator.isOverLimit(
                schedule: schedule(
                    limit: 2, sharedIDs: ["group-1", "group-2"],
                    limitConfig: .shared(exclude: nil)
                )
            ))
        )
    }

    @Test
    func testCombinedExperimentPoolsBothPriorGroups() async throws {
        // A pooled with its partner under group-a, B with its partner under
        // group-b. Combining them adds `shared` without either leaving its own
        // group, so A's tally now sees both partners' history.
        try await recordExecution(scheduleID: "a-partner", sharedIDs: ["group-a"])
        try await recordExecution(scheduleID: "b-partner", sharedIDs: ["group-b", "shared"])

        #expect(
            await evaluator.isOverLimit(
                schedule: schedule(
                    id: "a", limit: 2, sharedIDs: ["group-a", "shared"],
                    limitConfig: .shared(exclude: nil)
                )
            )
        )
    }

    @Test
    func testParsesMultipleSharedIDs() throws {
        let json = """
        {
          "id": "test-schedule",
          "type": "actions",
          "actions": { "foo": "bar" },
          "triggers": [],
          "ledger_config": { "shared_ids": ["group-2", "group-1", "group-1"] }
        }
        """
        let schedule = try JSONDecoder().decode(AutomationSchedule.self, from: Data(json.utf8))

        // Canonical form: de-duplicated and sorted, whatever order they arrive in.
        #expect(schedule.ledgerSharedIDs == ["group-1", "group-2"])
    }
}
