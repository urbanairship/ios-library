/* Copyright Airship and Contributors */

import Combine
import Foundation
import SwiftUI
@_spi(AirshipInternal) import AirshipBasement

/// Evaluates which trigger outcome batches should run for a given Thomas state snapshot.
/// Used by ``StateTriggerModifier`` and unit tests.
internal enum StateTriggerEvaluation {
    /// Updates `triggered` (persistent fired IDs) and returns outcome lists to process, in order.
    static func batchesToRun(
        triggers: [ThomasStateTriggers],
        state: AirshipJSON,
        triggered: inout Set<String>
    ) -> [[ThomasOutcome]] {
        var batches: [[ThomasOutcome]] = []
        for trigger in triggers {
            if triggered.contains(trigger.id), trigger.resetWhenStateMatches?.evaluate(json: state) == true {
                triggered.remove(trigger.id)
            }

            if !triggered.contains(trigger.id), trigger.triggerWhenStateMatches.evaluate(json: state) {
                triggered.insert(trigger.id)
                if let outcomes = trigger.onTrigger.outcomes ?? trigger.onTrigger.stateActions?.map(\.asOutcome) {
                    batches.append(outcomes)
                }
            }
        }
        return batches
    }
}

internal struct StateTriggerModifier: ViewModifier {
    let triggers: [ThomasStateTriggers]
    @EnvironmentObject private var thomasState: ThomasState

    @State private var triggered: Set<String> = Set()

    @ViewBuilder
    func body(content: Content) -> some View {
        content.airshipOnChangeOf(thomasState.state, initial: true) { state in
            var nextTriggered = triggered
            let batches = StateTriggerEvaluation.batchesToRun(
                triggers: triggers,
                state: state,
                triggered: &nextTriggered
            )
            triggered = nextTriggered
            for outcomes in batches {
                Task {
                    await thomasState.process(outcomes: outcomes)
                }
            }
        }
    }
}
