/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Combine

@available(iOS 13.0.0, tvOS 13.0, *)
struct FormController : View {
    
    let model: FormControllerModel
    let constraints: ViewConstraints
    @State var formState: FormState
    
    init(model: FormControllerModel, constraints: ViewConstraints) {
        self.model = model
        self.constraints = constraints
        self.formState = FormState(model.identifier) { children in
            let isValid = children.values.contains(where: { $0.isValid == false }) == false
            return FormInputData(isValid: isValid,
                                 value: .form(children))
        }
    }
    
    var body: some View {
        if (model.submit != nil) {
            ParentFormController(model: model, constraints: constraints, formState: formState)
        } else {
            ChildFormController(model: model, constraints: constraints, formState: formState)
        }
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
private struct ParentFormController : View {
    
    let model: FormControllerModel
    let constraints: ViewConstraints
    
    @ObservedObject var formState: FormState
    
    var body: some View {
        ViewFactory.createView(model: self.model.view, constraints: constraints)
            .environmentObject(formState)
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
private struct ChildFormController : View {
    let model: FormControllerModel
    let constraints: ViewConstraints
    
    @EnvironmentObject var parentFormState: FormState
    @ObservedObject var formState: FormState
    @State private var cancellable: AnyCancellable?

    var body: some View {
        return ViewFactory.createView(model: self.model.view, constraints: constraints)
            .environmentObject(formState)
            .onAppear {
                self.cancellable = self.formState.$data.sink { incoming in
                    self.parentFormState.updateFormInput(self.model.identifier,
                                                         data: incoming)
                }
            }
    }
}
