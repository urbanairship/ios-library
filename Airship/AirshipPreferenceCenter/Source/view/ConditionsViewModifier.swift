/* Copyright Airship and Contributors */


import SwiftUI

struct ConditionsViewModifier: ViewModifier {
    @StateObject
    var conditionsMonitor: ConditionsMonitor

    @Binding
    var binding: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        content
            .onReceive(conditionsMonitor.$isMet) { incoming in
                binding = incoming
            }
    }
}

extension View {

    @ViewBuilder
    func preferenceConditions(
        _ conditions: [PreferenceCenterConfig.Condition]?
    ) -> some View {
        self
    }

    @MainActor
    @ViewBuilder
    func preferenceConditions(
        _ conditions: [PreferenceCenterConfig.Condition]?,
        binding: Binding<Bool>
    ) -> some View {
        if let conditions = conditions {
            self.modifier(
                ConditionsViewModifier(
                    conditionsMonitor: ConditionsMonitor(
                        conditions: conditions
                    ),
                    binding: binding
                )
            )
        } else {
            self
        }
    }
}
