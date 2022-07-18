/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Combine

@available(iOS 13.0.0, tvOS 13.0, *)
internal struct FormEventHandlerViewModifier: ViewModifier {
    @EnvironmentObject var viewState: ViewState
    @EnvironmentObject var formState: FormState
    let eventHandlers: [EventHandler]
    let formInputID: String

    @ViewBuilder
    func body(content: Content) -> some View {
        let types = eventHandlers.map { $0.type }

        content.applyIf(types.contains(.tap)) { view in
            view.addTapGesture {
                applyStateChanges(type: .tap, formData: self.formState.data)
            }
        }
        .applyIf(types.contains(.show)) { view in
            view.onAppear {
                applyStateChanges(type: .show, formData: self.formState.data)
            }
        }
        .applyIf(types.contains(.hide)) { view in
            view.onDisappear {
                applyStateChanges(type: .hide, formData: self.formState.data)
            }
        }.applyIf(types.contains(.formInput)) { view in
            content.onReceive(self.formState.$data) { incoming in
                applyStateChanges(type: .formInput, formData: incoming)
            }
        }
    }

    func unwrapValue(_ formValue: FormValue?) -> Any? {
        switch(formValue) {
        case .toggle(let value): return value
        case .radio(let value): return value
        case .multipleCheckbox(let value): return value
        case .form(_, _, let value): return value.map { $0.toPayload() }
        case .text(let value): return value
        case .score(let value): return value
        case .none: return nil
        }
    }

    private func applyStateChanges(type: EventHandlerType,
                                   formData: FormInputData) {
        let value = unwrapValue(formData.formValue(identifier: formInputID))

        self.eventHandlers.forEach { eventHandler in
            if (eventHandler.type == type) {
                eventHandler.stateActions.forEach { action in
                    switch(action) {
                    case .setState(let details):
                        viewState.updateState(key: details.key, value: details.value?.unWrap())
                    case .clearState:
                        viewState.clearState()
                    case .formValue(let details):
                        viewState.updateState(key: details.key, value: value)
                    }
                }
            }
        }
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
internal struct EventHandlerViewModifier: ViewModifier {
    @EnvironmentObject var viewState: ViewState
    let eventHandlers: [EventHandler]

    @ViewBuilder
    func body(content: Content) -> some View {
        let types = eventHandlers.map { $0.type }

        content.applyIf(types.contains(.tap)) { view in
            view.addTapGesture {
                applyStateChanges(type: .tap)
            }
        }
        .applyIf(types.contains(.show)) { view in
            view.onAppear {
                applyStateChanges(type: .show)
            }
        }
        .applyIf(types.contains(.hide)) { view in
            view.onDisappear {
                applyStateChanges(type: .hide)
            }
        }
    }

    private func applyStateChanges(type: EventHandlerType) {
        self.eventHandlers.forEach { eventHandler in
            if (eventHandler.type == type) {
                eventHandler.stateActions.forEach { action in
                    switch(action) {
                    case .setState(let details):
                        viewState.updateState(key: details.key, value: details.value?.unWrap())
                    case .clearState:
                        viewState.clearState()
                    case .formValue(_):
                        AirshipLogger.error("Unable to process form value")
                    }
                }
            }
        }
    }
}



@available(iOS 13.0.0, tvOS 13.0, *)
extension View {

    @ViewBuilder
    func eventHandlers(_ eventHandlers: [EventHandler]?,
                       formInputID: String? = nil) -> some View {
        if let handlers = eventHandlers {
            if let formInputID = formInputID {
                self.modifier(FormEventHandlerViewModifier(eventHandlers: handlers, formInputID: formInputID))
            } else {
                self.modifier(EventHandlerViewModifier(eventHandlers: handlers))
            }

        } else {
            self
        }
    }
}

