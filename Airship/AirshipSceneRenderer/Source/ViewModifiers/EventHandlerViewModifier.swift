/* Copyright Airship and Contributors */

import Combine
import Foundation
import SwiftUI
@_spi(AirshipInternal) import AirshipBasement

extension EventHandlerViewModifier {

    /// Outcomes for handlers matching `type`, in declaration order (same as the view modifier).
    internal static func outcomes(
        for handlers: [ThomasEventHandler],
        type: ThomasEventHandler.EventType
    ) -> [ThomasOutcome] {
        handlers.filter { $0.type == type }.flatMap { $0.outcomes ?? $0.stateActions.map(\.asOutcome) }
    }

    /// Runs ``ThomasState/process(outcomes:actionsDelegate:)`` with the same delegation rules as tap / form handlers.
    internal static func processOutcomes(
        _ outcomes: [ThomasOutcome],
        thomasState: ThomasState,
        thomasEnvironment: ThomasEnvironment,
        layoutState: LayoutState?
    ) async {
        guard !outcomes.isEmpty else { return }
        await thomasState.process(
            outcomes: outcomes,
            actionsDelegate: { entry in
                switch entry {
                case .dismiss(let outcome):
                    thomasEnvironment.dismiss(
                        cancel: outcome.cancel ?? false,
                        layoutState: layoutState
                    )
                case .runAction(let outcome):
                    thomasEnvironment.runActions(
                        outcome.actions,
                        layoutState: layoutState
                    )
                case .formAction: break
                }
            }
        )
    }
}

internal struct EventHandlerViewModifier: ViewModifier {
    @EnvironmentObject var thomasEnvironment: ThomasEnvironment
    @EnvironmentObject var thomasState: ThomasState
    @EnvironmentObject var formState: ThomasFormState
    @EnvironmentObject var pagerState: PagerState

    @Environment(\.layoutState) private var layoutState

    let eventHandlers: [ThomasEventHandler]
    let formInputID: String?

    @ViewBuilder
    func body(content: Content) -> some View {
        let types = eventHandlers.map { $0.type }

        content.airshipApplyIf(types.contains(.tap)) { view in
            view.addTapGesture {
                handleEvent(type: .tap)
            }
            // A view that handles taps itself should not also fire an enclosing pager's
            // region tap gesture. Report its frame so the pager can skip taps on it.
            .reportPagerGestureExclusion()
        }
        .airshipApplyIf(types.contains(.formInput)) { view in
            if let formInputID {
                view.airshipOnChangeOf(self.formState.field(identifier: formInputID)?.input) { input in
                    handleEvent(type: .formInput, formFieldValue: input)
                }
            }
        }
    }

    private func handleEvent(
        type: ThomasEventHandler.EventType,
        formFieldValue: ThomasFormField.Value? = nil
    ) {
        let outcomes = Self.outcomes(for: eventHandlers, type: type)
        if outcomes.isEmpty {
            return
        }

        Task { [thomasState, thomasEnvironment, layoutState] in
            await Self.processOutcomes(
                outcomes,
                thomasState: thomasState,
                thomasEnvironment: thomasEnvironment,
                layoutState: layoutState
            )
        }
    }
}
