/* Copyright Airship and Contributors */

import Combine
import Foundation
import SwiftUI


struct FormController: View {

    let model: FormControllerModel
    let constraints: ViewConstraints
    @State var formState: FormState

    @MainActor
    init(model: FormControllerModel, constraints: ViewConstraints) {
        self.model = model
        self.constraints = constraints
        self.formState = FormState(
            identifier: self.model.identifier,
            formType: .form,
            formResponseType: self.model.responseType
        )
    }

    var body: some View {
        if model.submit != nil {
            ParentFormController(
                model: model,
                constraints: constraints,
                formState: formState
            )
        } else {
            ChildFormController(
                model: model,
                constraints: constraints,
                formState: formState
            )
        }
    }
}


private struct ParentFormController: View {

    let model: FormControllerModel
    let constraints: ViewConstraints

    @ObservedObject var formState: FormState
    @EnvironmentObject var thomasEnvironment: ThomasEnvironment
    @Environment(\.layoutState) var layoutState
    @State private var visibleCancellable: AnyCancellable?

    var body: some View {
        ViewFactory.createView(model: self.model.view, constraints: constraints)
            .background(self.model.backgroundColor)
            .border(self.model.border)
            .common(self.model, formInputID: self.model.identifier)
            .enableBehaviors(self.model.formEnableBehaviors) { enabled in
                self.formState.isEnabled = enabled
            }
            .environment(
                \.layoutState,
                layoutState.override(formState: formState)
            )
            .environmentObject(formState)
            .onAppear {
                self.visibleCancellable = self.formState.$isVisible.sink {
                    incoming in
                    if incoming {
                        self.thomasEnvironment.formDisplayed(
                            self.formState,
                            layoutState: layoutState.override(
                                formState: formState
                            )
                        )
                    }
                }
            }
    }
}


private struct ChildFormController: View {
    let model: FormControllerModel
    let constraints: ViewConstraints

    @EnvironmentObject var parentFormState: FormState
    @ObservedObject var formState: FormState

    var body: some View {
        return
            ViewFactory.createView(
                model: self.model.view,
                constraints: constraints
            )
            .background(self.model.backgroundColor)
            .border(self.model.border)
            .common(self.model, formInputID: self.model.identifier)
            .enableBehaviors(self.model.formEnableBehaviors) { enabled in
                self.formState.isEnabled = enabled
            }
            .environmentObject(formState)
            .onAppear {
                self.restoreFormState()
                self.formState.parentFormState = self.parentFormState
            }
    }

    private func restoreFormState() {
        guard
            let formData = self.parentFormState.data.formData(
                identifier: self.model.identifier
            ),
            case let .form(responseType, formType, children) = formData.value,
            responseType == self.model.responseType,
            case .form = formType
        else {
            return
        }

        children.forEach {
            self.formState.updateFormInput($0)
        }
    }
}


struct FormControllerDebug: View {
    @EnvironmentObject var state: FormState

    var body: some View {
        Text(String(describing: state.data.toPayload()))
    }
}
