/* Copyright Airship and Contributors */

import Combine
import Foundation
import SwiftUI


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
        let handlers = eventHandlers.filter { $0.type == type }

        // Process
        handlers.forEach { handler in
            handleStateAction(handler.stateActions, formFieldValue: formFieldValue)
        }
    }

    private func handleStateAction(
        _ stateActions: [ThomasStateAction],
        formFieldValue: ThomasFormField.Value?
    ) {
        thomasState.processStateActions(stateActions, formFieldValue: formFieldValue)
    }
}


