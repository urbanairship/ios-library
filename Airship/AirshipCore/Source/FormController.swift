/* Copyright Airship and Contributors */

import Combine
import Foundation
import SwiftUI


struct FormController: View {

    let info: ThomasViewInfo.FormController
    let constraints: ViewConstraints
    @StateObject var formState: FormState

    @MainActor
    init(info: ThomasViewInfo.FormController, constraints: ViewConstraints) {
        self.info = info
        self.constraints = constraints
        self._formState = StateObject(
            wrappedValue: FormState(
                identifier: info.properties.identifier,
                formType: .form,
                formResponseType: info.properties.responseType
            )
        )
    }

    var body: some View {
        if info.properties.submit != nil {
            ParentFormController(
                info: info,
                constraints: constraints,
                formState: formState
            )
        } else {
            ChildFormController(
                info: info,
                constraints: constraints,
                formState: formState
            )
        }
    }
}


private struct ParentFormController: View {

    let info: ThomasViewInfo.FormController
    let constraints: ViewConstraints

    @ObservedObject var formState: FormState
    @EnvironmentObject var thomasEnvironment: ThomasEnvironment
    @Environment(\.layoutState) var layoutState

    var body: some View {
        ViewFactory.createView(self.info.properties.view, constraints: constraints)
            .thomasCommon(self.info, formInputID: self.info.properties.identifier)
            .thomasEnableBehaviors(self.info.properties.formEnableBehaviors) { enabled in
                self.formState.isEnabled = enabled
            }
            .environment(
                \.layoutState,
                layoutState.override(formState: formState)
            )
            .environmentObject(formState)
            .airshipOnChangeOf(formState.isVisible) { [weak formState, weak thomasEnvironment] incoming in
                guard incoming, let formState, let thomasEnvironment else {
                    return
                }
                thomasEnvironment.formDisplayed(
                    formState,
                    layoutState: layoutState.override(
                        formState: formState
                    )
                )
            }
    }
}


private struct ChildFormController: View {
    let info: ThomasViewInfo.FormController
    let constraints: ViewConstraints

    @EnvironmentObject var parentFormState: FormState
    @ObservedObject var formState: FormState

    var body: some View {
        return
            ViewFactory.createView(
                self.info.properties.view,
                constraints: constraints
            )
            .thomasCommon(self.info, formInputID: self.info.properties.identifier)
            .thomasEnableBehaviors(self.info.properties.formEnableBehaviors) { enabled in
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
                identifier: self.info.properties.identifier
            ),
            case let .form(responseType, formType, children) = formData.value,
            responseType == self.info.properties.responseType,
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
