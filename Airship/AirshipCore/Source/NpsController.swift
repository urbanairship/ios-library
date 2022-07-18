/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Combine

@available(iOS 13.0.0, tvOS 13.0, *)
struct NpsController : View {
    let model: NpsControllerModel
    let constraints: ViewConstraints
    
    @State var formState: FormState
    
    init(model: NpsControllerModel, constraints: ViewConstraints) {
        self.model = model
        self.constraints = constraints
        self.formState = FormState(identifier: self.model.identifier,
                                   formType: .nps(self.model.npsIdentifier),
                                   formResponseType: self.model.responseType)
    }
    
    var body: some View {
        if (model.submit != nil) {
            ParentNpsController(model: model, constraints: constraints, formState: formState)
        } else {
            ChildNpsController(model: model, constraints: constraints, formState: formState)
        }
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
private struct ParentNpsController : View {
    let model: NpsControllerModel
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
            .environmentObject(formState)
            .environment(\.layoutState, layoutState.override(formState: formState))
            .onAppear {
                self.visibleCancellable = self.formState.$isVisible.sink { incoming in
                    if (incoming) {
                        self.thomasEnvironment.formDisplayed(self.formState,
                                                             layoutState: layoutState.override(formState: formState))
                    }
                }
            }
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
private struct ChildNpsController : View {
    let model: NpsControllerModel
    let constraints: ViewConstraints
    
    @EnvironmentObject var parentFormState: FormState
    @ObservedObject var formState: FormState
    @State private var dataCancellable: AnyCancellable?
    @State private var visibleCancellable: AnyCancellable?
    
    var body: some View {
        return ViewFactory.createView(model: self.model.view, constraints: constraints)
            .background(self.model.backgroundColor)
            .border(self.model.border)
            .common(self.model, formInputID: self.model.identifier)
            .enableBehaviors(self.model.formEnableBehaviors) { enabled in
                self.formState.isEnabled = enabled
            }
            .environmentObject(formState)
            .onAppear {
                restoreFormState()
                
                self.dataCancellable = self.formState.$data.sink { incoming in
                    self.parentFormState.updateFormInput(incoming)
                }
                
                self.visibleCancellable = self.formState.$isVisible.sink { incoming in
                    if (incoming) {
                        parentFormState.markVisible()
                    }
                }
            }
    }

    private func restoreFormState() {
        guard let formData = self.parentFormState.data.formData(identifier: self.model.identifier),
              case let .form(responseType, formType, children) = formData.value,
              responseType == self.model.responseType,
              case let .nps(scoreID) = formType,
              scoreID == self.model.npsIdentifier
        else {
            return
        }

        children.forEach {
            self.formState.updateFormInput($0)
        }
    }
}
