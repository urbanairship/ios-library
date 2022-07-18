import Foundation
import SwiftUI
import Combine

@available(iOS 13.0.0, tvOS 13.0, *)
struct RadioInputController : View {
    let model: RadioInputControllerModel
    let constraints: ViewConstraints
    
    @State private var cancellable: AnyCancellable?
    @EnvironmentObject var parentFormState: FormState
    @State var radioInputState: RadioInputState = RadioInputState()
    
    var body: some View {
        ViewFactory.createView(model: self.model.view, constraints: constraints)
            .constraints(constraints)
            .background(self.model.backgroundColor)
            .border(self.model.border)
            .common(self.model, formInputID: self.model.identifier)
            .accessible(self.model)
            .formElement()
            .environmentObject(radioInputState)
            .onAppear {
                restoreFormState()

                self.cancellable = self.radioInputState.$selectedItem.sink { incoming in
                    let data = FormInputData(self.model.identifier,
                                             value: .radio(incoming),
                                             attributeName: self.model.attributeName,
                                             attributeValue: radioInputState.attributeValue,
                                             isValid: incoming != nil || self.model.isRequired != true)
                    
                    self.parentFormState.updateFormInput(data)
                }
            }
    }

    private func restoreFormState() {
        guard case let .radio(value) = self.parentFormState.data.formValue(identifier: self.model.identifier),
              let value = value
        else {
            return
        }

        self.radioInputState.selectedItem = value
    }
}
