/* Copyright Airship and Contributors */

import Foundation
import Testing

@testable import AirshipCore
@testable @_spi(AirshipInternal) import AirshipSceneRenderer

@Suite("Outcomes", .timeLimit(.minutes(1)))
struct StateTriggerEvaluationTest {

    private func triggerWhenFlagTrue(
        id: String = "t1",
        onTrigger: ThomasStateTriggers.TriggerActions
    ) -> ThomasStateTriggers {
        ThomasStateTriggers(
            id: id,
            triggerWhenStateMatches: JSONPredicate(jsonMatcher: JSONMatcher(
                valueMatcher: .matcherWhereBooleanEquals(true),
                scope: ["flag"]
            )),
            resetWhenStateMatches: nil,
            onTrigger: onTrigger
        )
    }

    @Test
    func firesOnceWhenPredicateMatchesUsingStateActions() {
        let trigger = triggerWhenFlagTrue(
            onTrigger: .init(
                stateActions: [.setState(.init(key: "k", value: .string("v"), ttl: nil))],
                outcomes: nil
            )
        )
        var fired = Set<String>()
        let empty: AirshipJSON = .object([:])
        let match: AirshipJSON = .object(["flag": .bool(true)])

        #expect(StateTriggerEvaluation.batchesToRun(triggers: [trigger], state: empty, triggered: &fired).isEmpty)
        #expect(fired.isEmpty)

        let first = StateTriggerEvaluation.batchesToRun(triggers: [trigger], state: match, triggered: &fired)
        #expect(first.count == 1)
        #expect(first[0].count == 1)
        #expect(fired == ["t1"])

        let second = StateTriggerEvaluation.batchesToRun(triggers: [trigger], state: match, triggered: &fired)
        #expect(second.isEmpty)
    }

    @Test
    func prefersOutcomesOverStateActionsWhenBothPresent() {
        let trigger = triggerWhenFlagTrue(
            onTrigger: .init(
                stateActions: [.clearState],
                outcomes: [.dismiss(.init(cancel: true, identifier: "eval.dismiss"))]
            )
        )
        var fired = Set<String>()
        let match: AirshipJSON = .object(["flag": .bool(true)])
        let batches = StateTriggerEvaluation.batchesToRun(triggers: [trigger], state: match, triggered: &fired)
        #expect(batches.count == 1)
        guard case .dismiss(let d) = batches[0].first else {
            Issue.record("Expected dismiss outcome")
            return
        }
        #expect(d.cancel == true)
    }

    @Test
    func resetAllowsRefire() {
        let trigger = ThomasStateTriggers(
            id: "r1",
            triggerWhenStateMatches: JSONPredicate(jsonMatcher: JSONMatcher(
                valueMatcher: .matcherWhereBooleanEquals(true),
                scope: ["go"]
            )),
            resetWhenStateMatches: JSONPredicate(jsonMatcher: JSONMatcher(
                valueMatcher: .matcherWhereBooleanEquals(true),
                scope: ["reset"]
            )),
            onTrigger: .init(
                stateActions: [.clearState],
                outcomes: nil
            )
        )
        var fired = Set<String>()
        let go: AirshipJSON = .object(["go": .bool(true)])
        let goAndReset: AirshipJSON = .object(["go": .bool(true), "reset": .bool(true)])

        #expect(StateTriggerEvaluation.batchesToRun(triggers: [trigger], state: go, triggered: &fired).count == 1)
        #expect(fired == ["r1"])

        let afterReset = StateTriggerEvaluation.batchesToRun(triggers: [trigger], state: goAndReset, triggered: &fired)
        #expect(afterReset.count == 1)
        #expect(fired == ["r1"])
    }

    @MainActor
    @Test
    func batchesProcessThroughThomasState() async throws {
        let trigger = triggerWhenFlagTrue(
            onTrigger: .init(
                stateActions: nil,
                outcomes: [
                    ThomasStateAction.setState(.init(key: "marker", value: .bool(true), ttl: nil)).asOutcome
                ]
            )
        )
        let mutable = ThomasState.MutableState(initialState: .object([:]))
        let thomasState = ThomasState(mutableState: mutable, onStateChange: { _ in })
        var fired = Set<String>()
        let batches = StateTriggerEvaluation.batchesToRun(
            triggers: [trigger],
            state: .object(["flag": .bool(true)]),
            triggered: &fired
        )
        #expect(batches.count == 1)
        await thomasState.process(outcomes: batches[0])
        #expect(mutable.state.object?["marker"] == .bool(true))
    }
}
