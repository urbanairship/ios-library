/* Copyright Airship and Contributors */

import Foundation

@available(iOS 13.0.0, tvOS 13.0, *)
class FormState: ObservableObject {
    @Published var data: FormInputData
    @Published var isVisible: Bool = false
    @Published var isSubmitted: Bool = false
    
    private var children: [String: FormInputData] = [:]
    private let reducer: ([FormInputData]) -> FormInputData

    init(reducer: @escaping ([FormInputData]) -> FormInputData) {
        self.reducer = reducer
        self.data = reducer([])
    }
    
    func updateFormInput(_ data: FormInputData) {
        self.children[data.identifier] = data
        self.data = self.reducer(Array(self.children.values))
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
}

public struct FormInputData {
    private static let typeKey = "type"
    private static let valueKey = "value"
    private static let childrenKey = "children"
    private static let scoreIDKey = "score_id"
    
    let identifier: String
    let value: FormValue
    let attributeName: AttributeName?
    let attributeValue: AttributeValue?
    let isValid: Bool

    init(_ identifier: String,
         value: FormValue,
         attributeName: AttributeName? = nil,
         attributeValue: AttributeValue? = nil,
         isValid: Bool) {
        self.identifier = identifier
        self.value = value
        self.attributeName = attributeName
        self.attributeValue = attributeValue
        self.isValid = isValid
    }
    
    func attributes() -> [(AttributeName, AttributeValue)] {
        var result: [(AttributeName, AttributeValue)] = []
        if let attributeName = attributeName, let attributeValue = attributeValue {
            result.append((attributeName, attributeValue))
        }
        
        switch(self.value) {
        case .form(let children):
            children.forEach {
                result.append(contentsOf: $0.attributes())
            }
        case .nps(_, let children):
            children.forEach {
                result.append(contentsOf: $0.attributes())
            }
        default:
            break
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
            guard let value = value else {
                return nil
            }
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
        case .form(let value):
            var childrenMap: [String: Any] = [:]
            value.forEach { value in
                childrenMap[value.identifier] = value.getData()
            }
            
            guard !childrenMap.isEmpty else {
                return nil
            }
            return [
                FormInputData.typeKey: "form",
                FormInputData.childrenKey: childrenMap
            ]
        case .nps(let scoreID, let value):
            var childrenMap: [String: Any] = [:]
            value.forEach { value in
                childrenMap[value.identifier] = value.getData()
            }
            guard !childrenMap.isEmpty else {
                return nil
            }
            return [
                FormInputData.typeKey: "nps",
                FormInputData.scoreIDKey: scoreID,
                FormInputData.childrenKey: childrenMap
            ]
        }
    }
    
}

public enum FormValue {
    case toggle(Any?)
    case radio(Any?)
    case multipleCheckbox([Any]?)
    case form([FormInputData])
    case nps(String, [FormInputData])
    case text(String?)
    case score(Int?)
}
