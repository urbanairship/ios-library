/* Copyright Airship and Contributors */

import Combine
import Foundation
import SwiftUI


internal struct EventHandlerViewModifier: ViewModifier {
    @EnvironmentObject var thomasEnvironment: ThomasEnvironment
    @EnvironmentObject var viewState: ViewState
    @EnvironmentObject var formState: FormState
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

    func unwrapValue(_ formValue: FormValue?) -> Any? {
        switch formValue {
        case .toggle(let value): return value
        case .radio(let value): return value
        case .multipleCheckbox(let value): return value
        case .form(_, _, let value): return value.map { $0.toPayload() }
        case .text(let value): return value
        case .emailText(let value): return value
        case .score(let value): return value
        case .none: return nil
        }
    }

    private func handleEvent(type: ThomasEventHandler.EventType, formInputData: FormInputData? = nil) {
        let handlers = eventHandlers.filter { $0.type == type }

        // Process
        handlers.forEach { handler in
            handleStateAction(handler.stateActions, formInputData: formInputData)
        }
    }
    
    private func handleStateAction(
        _ stateActions: [ThomasStateAction],
        formInputData: FormInputData? = nil
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
                    let value = unwrapValue(formData.formValue(identifier: formInputID))
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
