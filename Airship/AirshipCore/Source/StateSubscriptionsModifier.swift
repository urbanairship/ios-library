/* Copyright Airship and Contributors */

import Combine
import Foundation
import SwiftUI

internal struct StateTriggerModifier: ViewModifier {
    let triggers: [ThomasStateTriggers]
    @EnvironmentObject var thomasState: ThomasState

    @State private var triggered: Set<String> = Set()

    @ViewBuilder
    func body(content: Content) -> some View {
        content.airshipOnChangeOf(thomasState.state, initial: true) { state in
            triggers.forEach { trigger in
                if triggered.contains(trigger.id), trigger.resetWhenStateMatches?.evaluate(json: state) == true {
                    triggered.remove(trigger.id)
                }

                if !triggered.contains(trigger.id), trigger.triggerWhenStateMatches.evaluate(json: state) {
                    triggered.insert(trigger.id)
                    if let stateActions = trigger.onTrigger.stateActions {
                        thomasState.processStateActions(stateActions)
                    }
                }
            }
        }
    }
}


extension View {

    @ViewBuilder
    func thomasStateTriggers(
        _ triggers: [ThomasStateTriggers]?
    ) -> some View {
        if let triggers = triggers, !triggers.isEmpty {
            self.modifier(
                StateTriggerModifier(
                    triggers: triggers
                )
            )
        } else {
            self
        }
    }
}
