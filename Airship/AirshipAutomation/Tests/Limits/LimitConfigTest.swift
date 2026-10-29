/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable @_spi(AirshipInternal) import AirshipAutomation
@_spi(AirshipInternal) import AirshipCore

struct LimitConfigTest {

    private let scheduleID = "schedule-A"
    private let otherScheduleID = "schedule-B"
    private let sharedID = "group-1"
    private let now = Date(timeIntervalSince1970: 10_000)

    private let variantAudienceID = "iteration-1"

    private var context: LedgerLimitContext {
        LedgerLimitContext(
            scheduleID: scheduleID,
            currentSharedIDs: [sharedID],
            currentVariantAudienceID: variantAudienceID
        )
    }

    private func execution(
        scheduleID: String? = nil,
        sharedIDs: [String] = [],
        triggerID: String? = nil,
        variantAudienceID: String? = nil,
        timestamp: Date? = nil,
        count: Int? = nil,
        result: LedgerExecutionResult = .succeeded,
        cancel: Bool? = nil
    ) -> LedgerEvent {
        return .execution(
            LedgerEvent.Execution(
                scheduleID: scheduleID ?? self.scheduleID,
                sharedIDs: sharedIDs.isEmpty ? nil : sharedIDs,
                triggerID: triggerID,
                variantAudienceID: variantAudienceID,
                timestamp: timestamp ?? self.now,
                count: count,
                result: result,
                cancel: cancel
            )
        )
    }

    private func triggered(
        scheduleID: String? = nil,
        variantAudienceID: String? = nil
    ) -> LedgerEvent {
        return .triggered(
            LedgerEvent.Triggered(
                scheduleID: scheduleID ?? self.scheduleID,
                sharedIDs: nil,
                triggerID: nil,
                variantAudienceID: variantAudienceID,
                timestamp: self.now,
                count: nil
            )
        )
    }

    private func isOverLimit(
        limit: UInt,
        events: [LedgerEvent],
        exclude: ExclusionSet? = nil,
        context: LedgerLimitContext? = nil
    ) -> Bool {
        return LedgerLimitEvaluator.isOverLimit(
            limit: limit,
            events: events,
            context: context ?? self.context,
            limitConfig: .shared(exclude: exclude),
            now: self.now
        )
    }

    // MARK: - Counting

    @Test
    func testCountsExecutionsAgainstLimit() {
        let events = [execution(), execution()]
        #expect(isOverLimit(limit: 2, events: events))
        #expect(!isOverLimit(limit: 3, events: events))
    }

    @Test
    func testTriggeredEventsDoNotCount() {
        let events = [triggered(), triggered(), execution()]
        #expect(!isOverLimit(limit: 2, events: events))
        #expect(isOverLimit(limit: 1, events: events))
    }

    @Test
    func testCountFieldIsSummed() {
        // A single backfill event standing in for 5 legacy executions.
        let events = [execution(count: 5, result: .backfill)]
        #expect(isOverLimit(limit: 5, events: events))
        #expect(!isOverLimit(limit: 6, events: events))
    }

    @Test
    func testEveryResultCounts() {
        let events = [
            execution(result: .succeeded),
            execution(result: .holdout),
            execution(result: .variantMiss),
            execution(result: .audienceMiss),
            execution(result: .backfill)
        ]
        #expect(isOverLimit(limit: 5, events: events))
    }

    // MARK: - Source matching

    @Test
    func testExcludeOtherSchedules() {
        let events = [
            execution(scheduleID: scheduleID),
            execution(scheduleID: otherScheduleID, sharedIDs: [sharedID])
        ]
        let exclude = ExclusionSet(or: [ExclusionRule(source: .otherSchedules, match: nil)])
        // Only the own-schedule execution remains counted.
        #expect(isOverLimit(limit: 1, events: events, exclude: exclude))
        #expect(!isOverLimit(limit: 2, events: events, exclude: exclude))
    }

    @Test
    func testExcludeOwnSchedule() {
        let events = [
            execution(scheduleID: scheduleID),
            execution(scheduleID: otherScheduleID, sharedIDs: [sharedID])
        ]
        let exclude = ExclusionSet(or: [ExclusionRule(source: .ownSchedule, match: nil)])
        #expect(isOverLimit(limit: 1, events: events, exclude: exclude))
        #expect(!isOverLimit(limit: 2, events: events, exclude: exclude))
    }

    @Test
    func testExcludeSpecificSchedule() {
        let events = [
            execution(scheduleID: scheduleID),
            execution(scheduleID: otherScheduleID, sharedIDs: [sharedID])
        ]
        let exclude = ExclusionSet(or: [ExclusionRule(source: .schedule(otherScheduleID), match: nil)])
        #expect(!isOverLimit(limit: 2, events: events, exclude: exclude))
        #expect(isOverLimit(limit: 1, events: events, exclude: exclude))
    }

    @Test
    func testAnySourceExcludesEverything() {
        let events = [execution(), execution(scheduleID: otherScheduleID)]
        let exclude = ExclusionSet(or: [ExclusionRule(source: .any, match: nil)])
        #expect(!isOverLimit(limit: 1, events: events, exclude: exclude))
    }

    // MARK: - Match filters

    @Test
    func testExcludeByResult() {
        let events = [
            execution(result: .succeeded),
            execution(result: .holdout)
        ]
        let exclude = ExclusionSet(or: [
            ExclusionRule(
                source: .any,
                match: .execution(.init(results: [.holdout]))
            )
        ])
        // The holdout execution is subtracted; only the succeeded one counts.
        #expect(isOverLimit(limit: 1, events: events, exclude: exclude))
        #expect(!isOverLimit(limit: 2, events: events, exclude: exclude))
    }

    @Test
    func testExcludeByCancel() {
        let events = [
            execution(cancel: true),
            execution(cancel: nil),
            execution(cancel: false)
        ]
        let exclude = ExclusionSet(or: [
            ExclusionRule(source: .any, match: .execution(.init(cancel: true)))
        ])
        // Only the cancel:true event is removed, leaving two.
        #expect(isOverLimit(limit: 2, events: events, exclude: exclude))
        #expect(!isOverLimit(limit: 3, events: events, exclude: exclude))
    }

    @Test
    func testExcludeByTriggerID() {
        let events = [
            execution(triggerID: "t1"),
            execution(triggerID: "t2")
        ]
        let exclude = ExclusionSet(or: [
            ExclusionRule(source: .any, match: .execution(.init(triggerID: "t1")))
        ])
        #expect(isOverLimit(limit: 1, events: events, exclude: exclude))
        #expect(!isOverLimit(limit: 2, events: events, exclude: exclude))
    }

    @Test
    func testExcludeByTimeBounds() {
        let old = execution(timestamp: Date(timeIntervalSince1970: 1_000))
        let recent = execution(timestamp: Date(timeIntervalSince1970: 9_000))
        // Subtract everything recorded before timestamp 5000.
        let exclude = ExclusionSet(or: [
            ExclusionRule(
                source: .any,
                match: .execution(
                    .init(timeBounds: AirshipTimeCriteria(end: Date(timeIntervalSince1970: 5_000)))
                )
            )
        ])
        #expect(!isOverLimit(limit: 2, events: [old, recent], exclude: exclude))
        #expect(isOverLimit(limit: 1, events: [old, recent], exclude: exclude))
    }

    // MARK: - Shared-group matching

    @Test
    func testExcludeCurrentSharedGroup() {
        let events = [
            execution(sharedIDs: [sharedID]),
            execution(sharedIDs: ["other-group"])
        ]
        let exclude = ExclusionSet(or: [
            ExclusionRule(source: .any, match: .execution(.init(sharedGroup: .current)))
        ])
        // Only the event in the current shared group is removed.
        #expect(isOverLimit(limit: 1, events: events, exclude: exclude))
        #expect(!isOverLimit(limit: 2, events: events, exclude: exclude))
    }

    @Test
    func testExcludeNotCurrentSharedGroup() {
        let events = [
            execution(sharedIDs: [sharedID]),
            execution(sharedIDs: ["stale-group"]),
            execution(sharedIDs: [])
        ]
        let exclude = ExclusionSet(or: [
            ExclusionRule(source: .any, match: .execution(.init(sharedGroup: .notCurrent)))
        ])
        // The stale group and the no-group event are dropped; only the current
        // group's event remains.
        #expect(isOverLimit(limit: 1, events: events, exclude: exclude))
        #expect(!isOverLimit(limit: 2, events: events, exclude: exclude))
    }

    @Test
    func testExcludeSharedGroupByID() {
        let events = [
            execution(sharedIDs: [sharedID]),
            execution(sharedIDs: ["target-group"])
        ]
        let exclude = ExclusionSet(or: [
            ExclusionRule(source: .any, match: .execution(.init(sharedGroup: .id("target-group"))))
        ])
        #expect(isOverLimit(limit: 1, events: events, exclude: exclude))
        #expect(!isOverLimit(limit: 2, events: events, exclude: exclude))
    }

    // MARK: - Variant-audience matching

    private func excludeVariantAudience(_ match: VariantAudienceMatch) -> ExclusionSet {
        ExclusionSet(or: [
            ExclusionRule(source: .any, match: .execution(.init(variantAudience: match)))
        ])
    }

    private var contextWithoutVariantAudience: LedgerLimitContext {
        LedgerLimitContext(
            scheduleID: scheduleID,
            currentSharedIDs: [sharedID],
            currentVariantAudienceID: nil
        )
    }

    @Test
    func testExcludeCurrentVariantAudience() {
        let events = [
            execution(variantAudienceID: variantAudienceID),
            execution(variantAudienceID: "iteration-0"),
            execution()
        ]
        // Only the current iteration's event is removed.
        let exclude = excludeVariantAudience(.current)
        #expect(isOverLimit(limit: 2, events: events, exclude: exclude))
        #expect(!isOverLimit(limit: 3, events: events, exclude: exclude))
    }

    @Test
    func testExcludeNotCurrentVariantAudience() {
        let events = [
            execution(variantAudienceID: variantAudienceID),
            execution(variantAudienceID: "iteration-0"),
            execution(variantAudienceID: "iteration--1")
        ]
        let exclude = excludeVariantAudience(.notCurrent)
        #expect(isOverLimit(limit: 1, events: events, exclude: exclude))
        #expect(!isOverLimit(limit: 2, events: events, exclude: exclude))
    }

    @Test
    func testExcludeVariantAudienceByID() {
        let events = [
            execution(variantAudienceID: variantAudienceID),
            execution(variantAudienceID: "iteration-0")
        ]
        let exclude = excludeVariantAudience(.id("iteration-0"))
        #expect(isOverLimit(limit: 1, events: events, exclude: exclude))
        #expect(!isOverLimit(limit: 2, events: events, exclude: exclude))
    }

    @Test
    func testEventsWithoutVariantAudienceNeverMatchAnyForm() {
        let events = [execution(), execution()]
        for match in [VariantAudienceMatch.current, .notCurrent, .id("iteration-0")] {
            // Nothing is excluded, so both events still count.
            #expect(isOverLimit(limit: 2, events: events, exclude: excludeVariantAudience(match)))
        }
    }

    @Test
    func testCurrentVariantAudienceMatchesNothingWithoutScheduleVariantAudience() {
        let events = [execution(variantAudienceID: variantAudienceID)]
        #expect(isOverLimit(
            limit: 1,
            events: events,
            exclude: excludeVariantAudience(.current),
            context: contextWithoutVariantAudience
        ))
    }

    @Test
    func testNotCurrentVariantAudienceWithoutScheduleVariantAudience() {
        // Every event recorded under a variant audience is "not current".
        let recorded = [execution(variantAudienceID: variantAudienceID)]
        #expect(!isOverLimit(
            limit: 1,
            events: recorded,
            exclude: excludeVariantAudience(.notCurrent),
            context: contextWithoutVariantAudience
        ))

        let unrecorded = [execution()]
        #expect(isOverLimit(
            limit: 1,
            events: unrecorded,
            exclude: excludeVariantAudience(.notCurrent),
            context: contextWithoutVariantAudience
        ))
    }

    @Test
    func testVariantAudienceCombinesWithOtherFilters() {
        // Every filter on a match must hold for an event to be excluded.
        let exclude = ExclusionSet(or: [
            ExclusionRule(
                source: .any,
                match: .execution(.init(sharedGroup: .current, variantAudience: .notCurrent))
            )
        ])
        let pastIteration = execution(sharedIDs: [sharedID], variantAudienceID: "iteration-0")
        let currentIteration = execution(sharedIDs: [sharedID], variantAudienceID: variantAudienceID)
        let otherGroup = execution(sharedIDs: ["other-group"], variantAudienceID: "iteration-0")

        #expect(!isOverLimit(limit: 1, events: [pastIteration], exclude: exclude))
        #expect(isOverLimit(limit: 1, events: [currentIteration], exclude: exclude))
        #expect(isOverLimit(limit: 1, events: [otherGroup], exclude: exclude))
    }

    @Test
    func testVariantAudienceMatchAppliesToTriggeredEvents() {
        let exclude = ExclusionSet(or: [
            ExclusionRule(source: .any, match: .triggered(.init(variantAudience: .current)))
        ])
        let triggeredEvent = triggered(variantAudienceID: variantAudienceID)
        #expect(ExclusionRule(source: .any, match: .triggered(.init(variantAudience: .current)))
            .matches(triggeredEvent, context: context, now: now))
        #expect(exclude.excludes(triggeredEvent, context: context, now: now))
        #expect(!exclude.excludes(triggered(), context: context, now: now))
    }

    // MARK: - Forward compatibility

    @Test
    func testUnknownSourceIsNoOp() throws {
        // A rule with an unrecognized source type must subtract nothing.
        let json = """
        { "or": [ { "source": { "type": "future_source" } } ] }
        """
        let exclude = try JSONDecoder().decode(ExclusionSet.self, from: Data(json.utf8))
        let events = [execution(), execution()]
        #expect(isOverLimit(limit: 2, events: events, exclude: exclude))
    }

    @Test
    func testUnknownMatchTypeIsNoOp() throws {
        let json = """
        { "or": [ { "source": { "type": "any" }, "match": { "type": "future_match" } } ] }
        """
        let exclude = try JSONDecoder().decode(ExclusionSet.self, from: Data(json.utf8))
        let events = [execution(), execution()]
        #expect(isOverLimit(limit: 2, events: events, exclude: exclude))
    }

    @Test
    func testUnknownResultValueIsDropped() throws {
        // A results list of only-unknown values matches nothing.
        let json = """
        { "or": [ { "source": { "type": "any" }, "match": { "type": "execution", "results": ["future_result"] } } ] }
        """
        let exclude = try JSONDecoder().decode(ExclusionSet.self, from: Data(json.utf8))
        let events = [execution(result: .succeeded)]
        #expect(isOverLimit(limit: 1, events: events, exclude: exclude))
    }

    @Test
    func testUnknownVariantAudienceIsNoOp() throws {
        let json = #"{"type": "execution", "variant_audience": {"type": "future_type"}}"#
        let match = try JSONDecoder().decode(LedgerEventMatch.self, from: Data(json.utf8))
        guard case .execution(let execution) = match else {
            Issue.record("Expected execution match")
            return
        }
        #expect(execution.variantAudience == .unknown)

        let events = [self.execution(variantAudienceID: variantAudienceID)]
        let exclude = excludeVariantAudience(.unknown)
        #expect(isOverLimit(limit: 1, events: events, exclude: exclude))
    }

    @Test
    func testUnknownSharedGroupIsNoOp() throws {
        let json = """
        { "or": [ { "source": { "type": "any" }, "match": { "type": "execution", "shared_group": { "type": "future" } } } ] }
        """
        let exclude = try JSONDecoder().decode(ExclusionSet.self, from: Data(json.utf8))
        let events = [execution(), execution()]
        #expect(isOverLimit(limit: 2, events: events, exclude: exclude))
    }

    // MARK: - Decoding

    @Test
    func testDecodeLimitConfig() throws {
        let json = """
        {
          "type": "shared",
          "exclude": {
            "or": [
              { "source": { "type": "other_schedules" } },
              {
                "source": { "type": "schedule", "schedule_id": "sched-x" },
                "match": {
                  "type": "execution",
                  "results": ["variant_miss", "holdout"],
                  "cancel": true,
                  "trigger_id": "trig-1",
                  "shared_group": { "type": "id", "shared_id": "grp" },
                  "variant_audience": { "type": "id", "variant_audience_id": "iteration-9" },
                  "time_bounds": { "start_timestamp": 1000, "end_timestamp": 2000 }
                }
              }
            ]
          }
        }
        """
        let config = try JSONDecoder().decode(LimitConfig.self, from: Data(json.utf8))

        guard case .shared(let excludeOpt) = config else {
            Issue.record("Expected .shared limitConfig")
            return
        }
        let exclude = try #require(excludeOpt)
        #expect(exclude.or.count == 2)
        #expect(exclude.or[0].source == .otherSchedules)
        #expect(exclude.or[0].match == nil)
        #expect(exclude.or[1].source == .schedule("sched-x"))

        guard case .execution(let match) = exclude.or[1].match else {
            Issue.record("Expected execution match")
            return
        }
        #expect(match.results == [.variantMiss, .holdout])
        #expect(match.cancel == true)
        #expect(match.triggerID == "trig-1")
        #expect(match.sharedGroup == .id("grp"))
        #expect(match.variantAudience == .id("iteration-9"))
    }

    @Test
    func testDecodeVariantAudienceForms() throws {
        func decode(_ audience: String) throws -> VariantAudienceMatch? {
            let json = #"{"type": "execution", "variant_audience": \#(audience)}"#
            guard case .execution(let match) = try JSONDecoder().decode(LedgerEventMatch.self, from: Data(json.utf8)) else {
                return nil
            }
            return match.variantAudience
        }

        #expect(try decode(#"{"type": "current"}"#) == .current)
        #expect(try decode(#"{"type": "not_current"}"#) == .notCurrent)
        #expect(try decode(#"{"type": "id", "variant_audience_id": "x"}"#) == .id("x"))

        // Absent means no filtering.
        let absent = try JSONDecoder().decode(
            LedgerEventMatch.self,
            from: Data(#"{"type": "triggered"}"#.utf8)
        )
        guard case .triggered(let triggeredMatch) = absent else {
            Issue.record("Expected triggered match")
            return
        }
        #expect(triggeredMatch.variantAudience == nil)
    }

    @Test
    func testDecodeSharedLimitConfigWithoutExclude() throws {
        // `exclude` is optional: a config with no exclusions decodes to nil, so
        // every execution counts against the cap.
        let config = try JSONDecoder().decode(LimitConfig.self, from: Data(#"{"type": "shared"}"#.utf8))
        guard case .shared(let exclude) = config else {
            Issue.record("Expected .shared limitConfig")
            return
        }
        #expect(exclude == nil)
    }

    @Test
    func testLimitConfigCodableRoundTrip() throws {
        let config = LimitConfig.shared(
            exclude: ExclusionSet(or: [
                ExclusionRule(source: .ownSchedule, match: .execution(.init(results: [.holdout]))),
                ExclusionRule(source: .schedule("x"), match: .triggered(.init(triggerID: "t"))),
                ExclusionRule(source: .any, match: .execution(.init(variantAudience: .notCurrent))),
                ExclusionRule(source: .any, match: .triggered(.init(variantAudience: .id("v")))),
                ExclusionRule(source: .otherSchedules, match: nil)
            ])
        )
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(LimitConfig.self, from: data)
        #expect(decoded == config)
    }

    @Test
    func testSelfLimitConfigCodableRoundTrip() throws {
        let config = LimitConfig.selfOnly(
            exclude: SelfExclusionSet(or: [
                SelfExclusionRule(match: .execution(.init(results: [.variantMiss])))
            ])
        )
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(LimitConfig.self, from: data)
        #expect(decoded == config)
    }

    // MARK: - Winner-selection scenarios (web-push-sdk#959)

    /// A pooled A/B group: two variants recorded executions under the shared
    /// group; the winner also has a holdout event.
    private func experimentEvents() -> [LedgerEvent] {
        return [
            execution(scheduleID: scheduleID, sharedIDs: [sharedID], result: .succeeded),
            execution(scheduleID: scheduleID, sharedIDs: [sharedID], result: .holdout),
            execution(scheduleID: otherScheduleID, sharedIDs: [sharedID], result: .succeeded),
            execution(scheduleID: otherScheduleID, sharedIDs: [sharedID], result: .succeeded)
        ]
    }

    @Test
    func testScenarioDifference() {
        // Pick up where the winner left off: exclude other schedules' events and
        // the winner's own holdout events. Only the winner's one succeeded
        // execution counts.
        let exclude = ExclusionSet(or: [
            ExclusionRule(source: .otherSchedules, match: nil),
            ExclusionRule(source: .ownSchedule, match: .execution(.init(results: [.holdout])))
        ])
        #expect(isOverLimit(limit: 1, events: experimentEvents(), exclude: exclude))
        #expect(!isOverLimit(limit: 2, events: experimentEvents(), exclude: exclude))
    }

    @Test
    func testScenarioContinue() {
        // Count all shared history, excluding only the winner's own holdout.
        // 3 succeeded executions remain (1 own + 2 other).
        let exclude = ExclusionSet(or: [
            ExclusionRule(source: .ownSchedule, match: .execution(.init(results: [.holdout])))
        ])
        #expect(isOverLimit(limit: 3, events: experimentEvents(), exclude: exclude))
        #expect(!isOverLimit(limit: 4, events: experimentEvents(), exclude: exclude))
    }

    @Test
    func testScenarioReset() {
        // Reset keeps own history via a new shared_id: other variants' events no
        // longer match the schedule's scope, so they wouldn't be fetched. With
        // no exclusion, only the events still in scope count. Here we simulate the
        // post-reset scope: the ledger returns just the winner's own events.
        let ownEvents = [
            execution(scheduleID: scheduleID, sharedIDs: [], result: .succeeded),
            execution(scheduleID: scheduleID, sharedIDs: [], result: .holdout)
        ]
        #expect(isOverLimit(limit: 2, events: ownEvents, exclude: nil))
        #expect(!isOverLimit(limit: 3, events: ownEvents, exclude: nil))
    }

    @Test
    func testScenarioFreshStart() {
        // New shared_id plus a time-bounded self exclusion drops all of the
        // winner's own history before the cutoff, for a clean slate.
        let cutoff = Date(timeIntervalSince1970: 9_999)
        let ownEvents = [
            execution(scheduleID: scheduleID, timestamp: Date(timeIntervalSince1970: 5_000)),
            execution(scheduleID: scheduleID, timestamp: Date(timeIntervalSince1970: 5_001))
        ]
        let exclude = ExclusionSet(or: [
            ExclusionRule(
                source: .ownSchedule,
                match: .execution(.init(timeBounds: AirshipTimeCriteria(end: cutoff)))
            )
        ])
        #expect(!isOverLimit(limit: 1, events: ownEvents, exclude: exclude))
    }

    // MARK: - Multiple shared groups

    @Test
    func testCurrentMatchesOnPartialOverlap() {
        // The schedule is in `group-1`; the event was recorded while its schedule
        // was in `group-1` and another. Sharing one group makes it current.
        let event = execution(sharedIDs: [sharedID, "other-group"])
        let rule = ExclusionRule(
            source: .any,
            match: .execution(.init(sharedGroup: .current))
        )

        #expect(rule.matches(event, context: context, now: now))
    }

    @Test
    func testNotCurrentNeedsEveryGroupToDiffer() {
        let overlapping = execution(sharedIDs: [sharedID, "other-group"])
        let disjoint = execution(sharedIDs: ["other-group", "third-group"])
        let rule = ExclusionRule(
            source: .any,
            match: .execution(.init(sharedGroup: .notCurrent))
        )

        #expect(!rule.matches(overlapping, context: context, now: now))
        #expect(rule.matches(disjoint, context: context, now: now))
    }

    @Test
    func testAbsoluteIDMatchesOneOfSeveralGroups() {
        let event = execution(sharedIDs: ["group-a", "group-b"])

        #expect(
            ExclusionRule(source: .any, match: .execution(.init(sharedGroup: .id("group-b"))))
                .matches(event, context: context, now: now)
        )
        #expect(
            !ExclusionRule(source: .any, match: .execution(.init(sharedGroup: .id("group-c"))))
                .matches(event, context: context, now: now)
        )
    }
}
