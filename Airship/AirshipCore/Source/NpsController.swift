/* Copyright Airship and Contributors */

import Combine
import Foundation
import SwiftUI


struct NpsController: View {
    let info: ThomasViewInfo.NPSController
    let constraints: ViewConstraints

    @StateObject var formState: ThomasFormState

    @MainActor
    init(info: ThomasViewInfo.NPSController, constraints: ViewConstraints) {
        self.info = info
        self.constraints = constraints
        self._formState = StateObject(
            wrappedValue: ThomasFormState(
                identifier: info.properties.identifier,
                formType: .nps(info.properties.npsIdentifier),
                formResponseType: info.properties.responseType
            )
        )
    }

    var body: some View {
        if self.info.properties.submit != nil {
            ParentNpsController(
                info: self.info,
                constraints: constraints,
                formState: formState
            )
        } else {
            ChildNpsController(
                info: self.info,
                constraints: constraints,
                formState: formState
            )
        }
    }
}


private struct ParentNpsController: View {
    let info: ThomasViewInfo.NPSController
    let constraints: ViewConstraints

    @ObservedObject var formState: ThomasFormState
    @EnvironmentObject var thomasEnvironment: ThomasEnvironment
    @Environment(\.layoutState) var layoutState

    var body: some View {
        ViewFactory.createView(self.info.properties.view, constraints: constraints)
            .thomasCommon(self.info, formInputID: self.info.properties.identifier)
            .thomasEnableBehaviors(self.info.properties.formEnableBehaviors) { enabled in
                self.formState.isEnabled = enabled
            }
            .environmentObject(formState)
            .environment(
                \.layoutState,
                layoutState.override(formState: formState)
            )
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


private struct ChildNpsController: View {
    let info: ThomasViewInfo.NPSController
    let constraints: ViewConstraints

    @EnvironmentObject var parentFormState: ThomasFormState
    @ObservedObject var formState: ThomasFormState

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
                restoreFormState()
                self.formState.parentFormState = self.parentFormState
            }
    }

    private func restoreFormState() {
        guard
            let formData = self.parentFormState.data.input(
                identifier: self.info.properties.identifier
            ),
            case let .npsForm(responseType, scoreID, children) = formData.value,
            responseType == self.info.properties.responseType,
            scoreID == self.info.properties.npsIdentifier
        else {
            return
        }

        children.forEach {
            self.formState.updateFormInput($0)
        }
    }
}
