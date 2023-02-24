/* Copyright Airship and Contributors */

import Foundation
import Combine

@available(iOS 13.0.0, tvOS 13.0, *)
class FormState: ObservableObject {
    @Published var data: FormInputData
    @Published var isVisible: Bool = false
    @Published var isSubmitted: Bool = false
    
    @Published var isEnabled: Bool = false {
        didSet {
            self.isFormInputEnabled = isEnabled && (self.parentFormState?.isFormInputEnabled ?? true)
        }
    }
    
    @Published private(set) var isFormInputEnabled: Bool = true
    
    @Published var parentFormState: FormState? = nil {
        didSet {
            subscriptions.removeAll()
            
            guard let newParent = self.parentFormState else { return }
            
            parentFormState?.$isFormInputEnabled.sink { [weak self] parentEnabled in
                guard let strongSelf = self else { return }
                strongSelf.isFormInputEnabled = strongSelf.isEnabled && parentEnabled
            }.store(in: &subscriptions)
            
            self.$data.sink { incoming in
                newParent.updateFormInput(incoming)
            }.store(in: &subscriptions)

            self.$isVisible.sink { incoming in
                if incoming {
                    newParent.markVisible()
                }
            }.store(in: &subscriptions)
            
        }
    }

    public let identifier: String
    public let formType: FormType
    public let formResponseType: String?
    private var children: [String: FormInputData] = [:]
    private var subscriptions: Set<AnyCancellable> = Set()

    init(identifier: String,
         formType: FormType,
         formResponseType: String?) {
        self.identifier = identifier
        self.formType = formType
        self.formResponseType = formResponseType
        
        self.data = FormInputData(
            identifier,
            value: .form(formResponseType, formType, []),
            isValid: false
        )
    }

    func updateFormInput(_ data: FormInputData) {
        self.children[data.identifier] = data
        
        let isValid = self.children.values.contains(
            where: { $0.isValid == false }
        ) == false

        self.data = FormInputData(
            identifier,
            value: .form(
                formResponseType,
                formType,
                Array(self.children.values)
            ),
            isValid: isValid
        )
    }

    func markVisible() {
        if (!self.isVisible) {
            self.isVisible = true
        }
    }
    
    func markSubmitted() {
        if (!self.isSubmitted) {
            self.isSubmitted = true
        }
    }

    
    var topFormState: FormState {
        guard let parent = self.parentFormState else {
            return self
        }
        return parent.topFormState
    }
}

public struct FormInputData {
    private static let typeKey = "type"
    private static let valueKey = "value"
    private static let childrenKey = "children"
    private static let scoreIDKey = "score_id"
    private static let responseTypeKey = "response_type"
    
    let identifier: String
    let value: FormValue
    let attributeName: AttributeName?
    let attributeValue: AttributeValue?
    let isValid: Bool

    init(
        _ identifier: String,
        value: FormValue,
        attributeName: AttributeName? = nil,
        attributeValue: AttributeValue? = nil,
        isValid: Bool
    ) {
        self.identifier = identifier
        self.value = value
        self.attributeName = attributeName
        self.attributeValue = attributeValue
        self.isValid = isValid
    }

    func formData(identifier: String) -> FormInputData? {
        guard self.identifier != identifier else {
            return self
        }

        if case let .form(_, _, children) = self.value {
            return children.first { child in
                child.identifier == identifier
            }
        }

        return nil
    }

    func formValue(identifier: String) -> FormValue? {
        return formData(identifier: identifier)?.value
    }

    func attributes() -> [(AttributeName, AttributeValue)] {
        var result: [(AttributeName, AttributeValue)] = []
        if let attributeName = attributeName, let attributeValue = attributeValue {
            result.append((attributeName, attributeValue))
        }

        if case let .form(_, _, children) = self.value {
            children.forEach { child in
                result.append(contentsOf: child.attributes())
            }
        }

        return result
    }
    
    func toPayload() -> [String: Any]? {
        guard let data = self.getData() else { return nil }
        return [self.identifier : data]
    }
    
    private func getData() -> [String: Any]? {
        switch(self.value) {
        case .toggle(let value):
            return [
                FormInputData.typeKey: "toggle",
                FormInputData.valueKey: value
            ]
        case .radio(let value):
            guard let value = value else {
                return nil
            }
            
            return [
                FormInputData.typeKey: "single_choice",
                FormInputData.valueKey: value
            ]
        case .multipleCheckbox(let value):
            guard let value = value else {
                return nil
            }
            return [
                FormInputData.typeKey: "multiple_choice",
                FormInputData.valueKey: value
            ]
        case .text(let value):
            guard let value = value else {
                return nil
            }
            return [
                FormInputData.typeKey: "text_input",
                FormInputData.valueKey: value
            ]
        case .score(let value):
            guard let value = value else {
                return nil
            }
            return [
                FormInputData.typeKey: "score",
                FormInputData.valueKey: value
            ]
        case .form(let responseType, let formType, let value):
            var childrenMap: [String: Any] = [:]
            value.forEach { value in
                childrenMap[value.identifier] = value.getData()
            }
            
            guard !childrenMap.isEmpty else {
                return nil
            }
            
            switch formType {
            case .form:
                return [
                    FormInputData.typeKey: "form",
                    FormInputData.childrenKey: childrenMap,
                    FormInputData.responseTypeKey: responseType as Any
                ]
            case .nps(let scoreID):
                return [
                    FormInputData.typeKey: "nps",
                    FormInputData.childrenKey: childrenMap,
                    FormInputData.responseTypeKey: responseType as Any,
                    FormInputData.scoreIDKey: scoreID
                ]
            }
        }
    }
}

public enum FormValue {
    case toggle(Bool)
    case radio(String?)
    case multipleCheckbox([String]?)
    case form(String?, FormType, [FormInputData])
    case text(String?)
    case score(Int?)

}

public enum FormType {
    case nps(String)
    case form
}
