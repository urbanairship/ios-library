/* Copyright Airship and Contributors */

import Foundation

@available(iOS 13.0.0, tvOS 13.0, *)
class FormState: ObservableObject {
    @Published var data: FormInputData
    @Published var isVisible: Bool = false
    @Published var attributes: [AttributeName: AttributeValue] = [:]
   
    let identifier: String
    
    private var children: [String: FormInputData] = [:]
    private let reducer: ([String: FormInputData]) -> FormInputData

    init(_ identifier: String, reducer: @escaping ([String: FormInputData]) -> FormInputData) {
        self.identifier = identifier
        self.reducer = reducer
        self.data = reducer(children)
    }
    
    func updateFormInput(_ identifier: String, data: FormInputData) {
        self.children[identifier] = data
        self.data = self.reducer(self.children)
    }
    
    func updateFormAttributes(name: AttributeName?, value: AttributeValue?) {
        guard let attributeName = name else {
            return
        }
        guard let attributeValue = value else {
            self.attributes.removeValue(forKey: attributeName)
            return
        }
      
        self.attributes.updateValue(attributeValue, forKey: attributeName)
    }
    
    func makeVisible() {
        if (!self.isVisible) {
            self.isVisible = true
        }
    }
}

public struct FormInputData {
    let isValid: Bool
    let value: FormValue
}

public enum FormValue {
    case checkbox(Any?)
    case radio(Any?)
    case multipleCheckbox([Any]?)
    case form([String: FormInputData])
    case nps(String, [String: FormInputData])
    case text(String?)
    case score(Int?)
}

