/* Copyright Airship and Contributors */

import Foundation
import Combine

@MainActor
class ThomasFormState: ObservableObject {
    @Published var data: ThomasFormInput
    @Published var isVisible: Bool = false
    @Published var isSubmitted: Bool = false

    @Published var isEnabled: Bool = true {
        didSet {
            self.isFormInputEnabled = isEnabled && (self.parentFormState?.isFormInputEnabled ?? true)
        }
    }

    @Published private(set) var isFormInputEnabled: Bool = true

    @Published var parentFormState: ThomasFormState? = nil {
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

    enum FormType: Sendable {
        case nps(String)
        case form

        fileprivate func makeFormData(
            identifier: String,
            responseType: String?,
            children: [ThomasFormInput],
            isValid: Bool
        ) -> ThomasFormInput {
            return switch(self) {
            case .form:
                ThomasFormInput(
                    identifier,
                    value: .form(responseType: responseType, children: children),
                    isValid: isValid
                )
            case .nps(let scoreID):
                ThomasFormInput(
                    identifier,
                    value: .npsForm(responseType: responseType, scoreID: scoreID, children: children),
                    isValid: isValid
                )
            }
        }
    }

    public let identifier: String
    public let formType: FormType
    public let formResponseType: String?
    private var children: [String: ThomasFormInput] = [:]
    private var subscriptions: Set<AnyCancellable> = Set()

    init(
        identifier: String,
        formType: FormType,
        formResponseType: String?
    ) {
        self.identifier = identifier
        self.formType = formType
        self.formResponseType = formResponseType

        self.data = formType.makeFormData(
            identifier: identifier,
            responseType: formResponseType,
            children: [],
            isValid: false
        )
    }

    func updateFormInput(_ data: ThomasFormInput) {
        self.children[data.identifier] = data

        let childrenValid =
            self.children.values.contains(
                where: { $0.isValid == false }
            ) == false

        self.data = formType.makeFormData(
            identifier: identifier,
            responseType: formResponseType,
            children: Array(self.children.values),
            isValid: childrenValid && !children.isEmpty
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


    var topFormState: ThomasFormState {
        guard let parent = self.parentFormState else {
            return self
        }
        return parent.topFormState
    }
}
