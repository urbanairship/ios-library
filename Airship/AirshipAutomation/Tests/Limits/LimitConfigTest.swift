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

    private var context: LedgerLimitContext {
        LedgerLimitContext(scheduleID: scheduleID, currentSharedID: sharedID)
    }

    private func execution(
        scheduleID: String? = nil,
        sharedID: String? = nil,
        triggerID: String? = nil,
        timestamp: Date? = nil,
        count: Int? = nil,
        result: LedgerExecutionResult = .succeeded,
        cancel: Bool? = nil
    ) -> LedgerEvent {
        return .execution(
            LedgerEvent.Execution(
                scheduleID: scheduleID ?? self.scheduleID,
                sharedID: sharedID,
                triggerID: triggerID,
                timestamp: timestamp ?? self.now,
                count: count,
                result: result,
                cancel: cancel
            )
        )
    }

    private func triggered(scheduleID: String? = nil) -> LedgerEvent {
        return .triggered(
            LedgerEvent.Triggered(
                scheduleID: scheduleID ?? self.scheduleID,
                sharedID: nil,
                triggerID: nil,
                timestamp: self.now,
                count: nil
            )
        )
    }

    private func isOverLimit(
        limit: UInt,
        events: [LedgerEvent],
        exclude: ExclusionSet? = nil
    ) -> Bool {
        return LedgerLimitEvaluator.isOverLimit(
            limit: limit,
            events: events,
            context: self.context,
            exclude: exclude,
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
            execution(result: .control),
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
            execution(scheduleID: otherScheduleID, sharedID: sharedID)
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
            execution(scheduleID: otherScheduleID, sharedID: sharedID)
        ]
        let exclude = ExclusionSet(or: [ExclusionRule(source: .ownSchedule, match: nil)])
        #expect(isOverLimit(limit: 1, events: events, exclude: exclude))
        #expect(!isOverLimit(limit: 2, events: events, exclude: exclude))
    }

    @Test
    func testExcludeSpecificSchedule() {
        let events = [
            execution(scheduleID: scheduleID),
            execution(scheduleID: otherScheduleID, sharedID: sharedID)
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
            execution(result: .control)
        ]
        let exclude = ExclusionSet(or: [
            ExclusionRule(
                source: .any,
                match: .execution(.init(results: [.control]))
            )
        ])
        // The control execution is subtracted; only the succeeded one counts.
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
            execution(sharedID: sharedID),
            execution(sharedID: "other-group")
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
            execution(sharedID: sharedID),
            execution(sharedID: "stale-group"),
            execution(sharedID: nil)
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
            execution(sharedID: sharedID),
            execution(sharedID: "target-group")
        ]
        let exclude = ExclusionSet(or: [
            ExclusionRule(source: .any, match: .execution(.init(sharedGroup: .id("target-group"))))
        ])
        #expect(isOverLimit(limit: 1, events: events, exclude: exclude))
        #expect(!isOverLimit(limit: 2, events: events, exclude: exclude))
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
          "exclude": {
            "or": [
              { "source": { "type": "other_schedules" } },
              {
                "source": { "type": "schedule", "schedule_id": "sched-x" },
                "match": {
                  "type": "execution",
                  "results": ["control", "holdout"],
                  "cancel": true,
                  "trigger_id": "trig-1",
                  "shared_group": { "type": "id", "shared_id": "grp" },
                  "time_bounds": { "start_timestamp": 1000, "end_timestamp": 2000 }
                }
              }
            ]
          }
        }
        """
        let config = try JSONDecoder().decode(LimitConfig.self, from: Data(json.utf8))

        let exclude = try #require(config.exclude)
        #expect(exclude.or.count == 2)
        #expect(exclude.or[0].source == .otherSchedules)
        #expect(exclude.or[0].match == nil)
        #expect(exclude.or[1].source == .schedule("sched-x"))

        guard case .execution(let match) = exclude.or[1].match else {
            Issue.record("Expected execution match")
            return
        }
        #expect(match.results == [.control, .holdout])
        #expect(match.cancel == true)
        #expect(match.triggerID == "trig-1")
        #expect(match.sharedGroup == .id("grp"))
    }

    @Test
    func testDecodeLimitConfigWithoutExclude() throws {
        // `exclude` is optional: a config with no exclusions decodes to nil, so
        // every execution counts against the cap.
        let config = try JSONDecoder().decode(LimitConfig.self, from: Data("{}".utf8))
        #expect(config.exclude == nil)
    }

    @Test
    func testLimitConfigCodableRoundTrip() throws {
        let config = LimitConfig(
            exclude: ExclusionSet(or: [
                ExclusionRule(source: .ownSchedule, match: .execution(.init(results: [.control]))),
                ExclusionRule(source: .schedule("x"), match: .triggered(.init(triggerID: "t"))),
                ExclusionRule(source: .otherSchedules, match: nil)
            ])
        )
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(LimitConfig.self, from: data)
        #expect(decoded == config)
    }

    // MARK: - Winner-selection scenarios (web-push-sdk#959)

    /// A pooled A/B group: two variants recorded executions under the shared
    /// group; the winner also has a variant-control event.
    private func experimentEvents() -> [LedgerEvent] {
        return [
            execution(scheduleID: scheduleID, sharedID: sharedID, result: .succeeded),
            execution(scheduleID: scheduleID, sharedID: sharedID, result: .control),
            execution(scheduleID: otherScheduleID, sharedID: sharedID, result: .succeeded),
            execution(scheduleID: otherScheduleID, sharedID: sharedID, result: .succeeded)
        ]
    }

    @Test
    func testScenarioDifference() {
        // Pick up where the winner left off: exclude other schedules' events and
        // the winner's own control events. Only the winner's one succeeded
        // execution counts.
        let exclude = ExclusionSet(or: [
            ExclusionRule(source: .otherSchedules, match: nil),
            ExclusionRule(source: .ownSchedule, match: .execution(.init(results: [.control])))
        ])
        #expect(isOverLimit(limit: 1, events: experimentEvents(), exclude: exclude))
        #expect(!isOverLimit(limit: 2, events: experimentEvents(), exclude: exclude))
    }

    @Test
    func testScenarioContinue() {
        // Count all shared history, excluding only the winner's own control.
        // 3 succeeded executions remain (1 own + 2 other).
        let exclude = ExclusionSet(or: [
            ExclusionRule(source: .ownSchedule, match: .execution(.init(results: [.control])))
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
            execution(scheduleID: scheduleID, sharedID: nil, result: .succeeded),
            execution(scheduleID: scheduleID, sharedID: nil, result: .control)
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
}
