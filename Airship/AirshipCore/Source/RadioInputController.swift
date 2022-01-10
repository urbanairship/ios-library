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
            .background(model.backgroundColor)
            .border(model.border)
            .viewAccessibility(label: self.model.contentDescription)
            .environmentObject(radioInputState)
            .onAppear {
                self.cancellable = self.radioInputState.$selectedItem.sink { incoming in
                    let data = FormInputData(self.model.identifier,
                                             value: .radio(incoming),
                                             attributeName: self.model.attributeName,
                                             attributeValue: radioInputState.attributeValue,
                                             isValid: incoming != nil || self.model.isRequired == false)
                    
                    self.parentFormState.updateFormInput(data)
                }
            }
    }
}
