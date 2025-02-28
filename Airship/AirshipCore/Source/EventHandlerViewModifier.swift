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
        .airshipApplyIf(types.contains(.formInput) && formInputID != nil) { view in
            view.onReceive(self.formState.$data) { incoming in
                handleEvent(type: .formInput, formInput: incoming)
            }
        }
    }

    private func handleEvent(type: ThomasEventHandler.EventType, formInput: ThomasFormInput? = nil) {
        let handlers = eventHandlers.filter { $0.type == type }

        // Process
        handlers.forEach { handler in
            handleStateAction(handler.stateActions, formInput: formInput)
        }
    }
    
    private func handleStateAction(
        _ stateActions: [ThomasStateAction],
        formInput: ThomasFormInput? = nil
    ) {
        thomasState.processStateActions(stateActions, formInput: formInput)
    }
}


extension View {

    @ViewBuilder
    func thomasEventHandlers(
        _ eventHandlers: [ThomasEventHandler]?,
        formInputID: String? = nil
    ) -> some View {

        if let handlers = eventHandlers {
            self.modifier(
                EventHandlerViewModifier(
                    eventHandlers: handlers,
                    formInputID: formInputID
                )
            )
        } else {
            self
        }
    }
}
