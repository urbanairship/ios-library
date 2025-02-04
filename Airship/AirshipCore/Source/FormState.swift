/* Copyright Airship and Contributors */

import Foundation
import Combine

@MainActor
class FormState: ObservableObject {
    @Published var data: FormInputData
    @Published var isVisible: Bool = false
    @Published var isSubmitted: Bool = false
    
    @Published var isEnabled: Bool = true {
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
                guard let self else { return }
                self.isFormInputEnabled = self.isEnabled && parentEnabled
            }.store(in: &subscriptions)
            
            self.$data.sink { [weak newParent] incoming in
                newParent?.updateFormInput(incoming)
            }.store(in: &subscriptions)

            self.$isVisible.sink { [weak newParent] incoming in
                if incoming {
                    newParent?.markVisible()
                }
            }.store(in: &subscriptions)
            
        }
    }

    public let identifier: String
    public let formType: FormType
    public let formResponseType: String?
    private var children: [String: FormInputData] = [:]
    private var subscriptions: Set<AnyCancellable> = Set()

    init(
        identifier: String,
        formType: FormType,
        formResponseType: String?
    ) {
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

        let isValid =
            self.children.values.contains(
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
        if !self.isVisible {
            self.isVisible = true
        }
    }

    func markSubmitted() {
        if !self.isSubmitted {
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

    enum ChannelRegistration {
        case email(String, ThomasEmailRegistrationOptions)
    }
    
    private static let typeKey = "type"
    private static let valueKey = "value"
    private static let childrenKey = "children"
    private static let scoreIDKey = "score_id"
    private static let responseTypeKey = "response_type"

    let identifier: String
    let value: FormValue
    let attributeName: ThomasAttributeName?
    let attributeValue: ThomasAttributeValue?
    let isValid: Bool
    let channelRegistration: ChannelRegistration?

    init(
        _ identifier: String,
        value: FormValue,
        attributeName: ThomasAttributeName? = nil,
        attributeValue: ThomasAttributeValue? = nil,
        channelRegistration: ChannelRegistration? = nil,
        isValid: Bool
    ) {
        self.identifier = identifier
        self.value = value
        self.attributeName = attributeName
        self.attributeValue = attributeValue
        self.channelRegistration = channelRegistration
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

    var attributes: [(ThomasAttributeName, ThomasAttributeValue)] {
        var result: [(ThomasAttributeName, ThomasAttributeValue)] = []
        if let attributeName, let attributeValue, isValid {
            result.append((attributeName, attributeValue))
        }

        if case let .form(_, _, children) = self.value {
            children.forEach { child in
                result.append(contentsOf: child.attributes)
            }
        }

        return result
    }

    var channels: [ChannelRegistration] {
        var result: [ChannelRegistration] = []
        if let channelRegistration, isValid {
            result.append(channelRegistration)
        }

        if case let .form(_, _, children) = self.value {
            children.forEach { child in
                result.append(contentsOf: child.channels)
            }
        }

        return result
    }

    func toPayload() -> AirshipJSON {
        guard let data = self.getData() else { return AirshipJSON.object([:]) }
        do {
            return try AirshipJSON.wrap([self.identifier: data])
        } catch {
            AirshipLogger.error("Failed to wrap form data \(error)")
        }
        return AirshipJSON.object([:])
    }

    func getData() -> [String: Any]? {
        switch self.value {
        case .toggle(let value):
            return [
                FormInputData.typeKey: "toggle",
                FormInputData.valueKey: value,
            ]
        case .radio(let value):
            guard let value = value else {
                return nil
            }

            return [
                FormInputData.typeKey: "single_choice",
                FormInputData.valueKey: value,
            ]
        case .multipleCheckbox(let value):
            guard let value = value else {
                return nil
            }
            return [
                FormInputData.typeKey: "multiple_choice",
                FormInputData.valueKey: value,
            ]
        case .text(let value):
            guard let value = value else {
                return nil
            }

            return [
                FormInputData.typeKey: "text_input",
                FormInputData.valueKey: value,
            ]
        case .emailText(let value):
            guard let value = value else {
                return nil
            }

            return [
                FormInputData.typeKey: "email_input",
                FormInputData.valueKey: value,
            ]
        case .score(let value):
            guard let value = value else {
                return nil
            }
            return [
                FormInputData.typeKey: "score",
                FormInputData.valueKey: value,
            ]
        case .form(let responseType, let formType, let value):
            var childrenMap: [String: Any] = [:]
            value.forEach { value in
                childrenMap[value.identifier] = value.getData()
            }

            switch formType {
            case .form:
                return [
                    FormInputData.typeKey: "form",
                    FormInputData.childrenKey: childrenMap,
                    FormInputData.responseTypeKey: responseType as Any,
                ]
            case .nps(let scoreID):
                return [
                    FormInputData.typeKey: "nps",
                    FormInputData.childrenKey: childrenMap,
                    FormInputData.responseTypeKey: responseType as Any,
                    FormInputData.scoreIDKey: scoreID,
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
    case emailText(String?)
    case score(Int?)
}

public enum FormType {
    case nps(String)
    case form
}
