/* Copyright Airship and Contributors */

import Combine
import Foundation
import SwiftUI


internal struct EventHandlerViewModifier: ViewModifier {
    @EnvironmentObject var thomasEnvironment: ThomasEnvironment
    @EnvironmentObject var viewState: ViewState
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
                handleEvent(type: .formInput, formInputData: incoming)
            }
        }
    }

    private func handleEvent(type: ThomasEventHandler.EventType, formInputData: ThomasFormInput? = nil) {
        let handlers = eventHandlers.filter { $0.type == type }

        // Process
        handlers.forEach { handler in
            handleStateAction(handler.stateActions, formInputData: formInputData)
        }
    }
    
    private func handleStateAction(
        _ stateActions: [ThomasStateAction],
        formInputData: ThomasFormInput? = nil
    ) {
        stateActions.forEach { action in
            switch action {
            case .setState(let details):
                viewState.updateState(
                    key: details.key,
                    value: details.value?.unWrap()
                )
            case .clearState:
                viewState.clearState()
            case .formValue(let details):
                if let formInputID {
                    let formData = formInputData ?? self.formState.data
                    let value = formData.input(identifier: formInputID)?.value.unwrappedValue
                    viewState.updateState(key: details.key, value: value)
                }
            }
        }
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
