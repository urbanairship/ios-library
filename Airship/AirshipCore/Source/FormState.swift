/* Copyright Airship and Contributors */

import Foundation

@available(iOS 13.0.0, tvOS 13.0, *)
class FormState: ObservableObject {
    @Published var data: FormInputData
    let formIdentifier: String
    
    private var children: [String: FormInputData] = [:]
    private let reducer: ([String: FormInputData]) -> FormInputData
    var result: [String: Any]? {
        data.toDictionary()
    }

    init(_ identifier: String, reducer: @escaping ([String: FormInputData]) -> FormInputData) {
        self.formIdentifier = identifier
        self.reducer = reducer
        self.data = reducer(children)
    }
    
    func updateFormInput(_ identifier: String, data: FormInputData) {
        self.children[identifier] = data
        self.data = self.reducer(self.children)
    }
}

public struct FormInputData {
    let isValid: Bool
    let value: FormValue
}

public enum FormValue {
    case checkbox(Bool?)
    case radio(String?)
    case multipleCheckbox([String]?)
    case form([String: FormInputData])
    case nps(String, [String: FormInputData])
    case text(String?)
    case score(Int?)
}


// TODO: Consider moving the extensions to the survey event
private extension FormValue {
    var typeName: String {
        switch(self) {
        case .checkbox(_):
            return "checkbox"
        case .radio(_):
            return "single_choice"
        case .multipleCheckbox(_):
            return "multiple_choice"
        case .form(_):
            return "form"
        case .nps(_, _):
            return "nps"
        case .text(_):
            return "text"
        case .score(_):
            return "score"
        }
    }
}

extension FormInputData {
    private static let typeKey = "type"
    private static let valueKey = "value"
    private static let childrenKey = "children"
    private static let scoreIdKey = "score_id"
    
    func toDictionary() -> [String: Any]? {
        switch(self.value) {
        case .checkbox(let value):
            guard let value = value else {
                return nil
            }
            return [
                FormInputData.typeKey: self.value.typeName,
                FormInputData.valueKey: value
            ]
        case .radio(let value):
            guard let value = value else {
                return nil
            }
            
            return [
                FormInputData.typeKey: self.value.typeName,
                FormInputData.valueKey: value
            ]
        case .multipleCheckbox(let value):
            guard let value = value else {
                return nil
            }
            return [
                FormInputData.typeKey: self.value.typeName,
                FormInputData.valueKey: value
            ]
        case .text(let value):
            guard let value = value else {
                return nil
            }
            return [
                FormInputData.typeKey: self.value.typeName,
                FormInputData.valueKey: value
            ]
        case .score(let value):
            guard let value = value else {
                return nil
            }
            return [
                FormInputData.typeKey: self.value.typeName,
                FormInputData.valueKey: value
            ]
        case .form(let value):
            var childrenMap: [String: Any] = [:]
            value.forEach { key, value in
                childrenMap[key] = value.toDictionary()
            }
            
            guard !childrenMap.isEmpty else {
                return nil
            }
            return [
                FormInputData.valueKey: self.value.typeName,
                FormInputData.childrenKey: childrenMap
            ]
        case .nps(let identifier, let value):
            var childrenMap: [String: Any] = [:]
            value.forEach { key, value in
                childrenMap[key] = value.toDictionary()
            }
            guard !childrenMap.isEmpty else {
                return nil
            }
            return [
                FormInputData.valueKey: self.value.typeName,
                FormInputData.scoreIdKey: identifier,
                FormInputData.childrenKey: childrenMap
            ]
        }
        
    }
}
