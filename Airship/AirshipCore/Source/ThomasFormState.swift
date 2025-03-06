/* Copyright Airship and Contributors */

import Foundation
import Combine

@MainActor
class ThomasFormState: ObservableObject {

    struct Child {
        var input: ThomasFormInput
    }

    private static let minAsyncValidationTime: TimeInterval = 1.0

    enum FormType: Sendable {
        case nps(String)
        case form
    }

    @Published
    var status: ThomasFormStatus = .pendingValidation {
        didSet {
            updateFormInputEnabled(
                isParentEnabled: parentFormState?.isFormInputEnabled
            )
        }
    }

    @Published
    var data: ThomasFormInput

    @Published
    var isVisible: Bool = false

    @Published
    var isEnabled: Bool = true {
        didSet {
            updateFormInputEnabled(
                isParentEnabled: parentFormState?.isFormInputEnabled
            )
        }
    }

    @Published
    var isFormInputEnabled: Bool = true

    @Published
    var parentFormState: ThomasFormState? = nil {
        didSet {
            subscriptions.removeAll()

            guard let newParent = self.parentFormState else { return }

            parentFormState?.$isFormInputEnabled.sink { [weak self] parentEnabled in
                self?.updateFormInputEnabled(isParentEnabled: parentEnabled)
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

    var topFormState: ThomasFormState {
        guard let parent = self.parentFormState else {
            return self
        }
        return parent.topFormState
    }

    let validationMode: ThomasFormValidationMode
    let identifier: String
    let formType: FormType
    let formResponseType: String?

    private var children: [String: Child] = [:]
    private var subscriptions: Set<AnyCancellable> = Set()
    private var validationTask: Task<Bool, Never>?
    private var childResults: [String: ThomasFormStatus.ChildValidationStatus] = [:]

    init(
        identifier: String,
        formType: FormType,
        formResponseType: String?,
        validationMode: ThomasFormValidationMode
    ) {
        self.identifier = identifier
        self.formType = formType
        self.formResponseType = formResponseType
        self.validationMode = validationMode

        self.data = formType.makeFormData(
            identifier: identifier,
            responseType: formResponseType,
            children: [],
            validator: .just(false)
        )
    }

    func validate() async -> Bool {
        validationTask?.cancel()

        guard let result = self.validateChildrenSync() else {
            self.status = .validating
            let task = Task { @MainActor [weak self] in
                return await self?.validateChildrenAsync() ?? false
            }
            validationTask = task
            return await task.value
        }

        return result
    }

    func updateFormInput(_ data: ThomasFormInput) {
        guard self.status != .submitted else { return }
        validationTask?.cancel()

        // Remove the invalid flag if we know the incoming value is not valid
        // This helps prevent removing the invalid status for things like checkbox
        // controllers if they have yet to select the right number of items.
        if childResults[data.identifier] != .invalid || data.validator.result != .invalid {
            childResults[data.identifier] = .pendingValidation
        }

        self.children[data.identifier] = Child(input: data)

        self.data = formType.makeFormData(
            identifier: identifier,
            responseType: formResponseType,
            children: Array(self.children.values.map { $0.input }),
            validator: .async(earlyValidation: .never) { [weak self] in
                await self?.validate() ?? false
            }
        )

        switch(validationMode) {
        case .onDemand:
            updateValidationStatusForPending()
        case .immediate:
            guard validateChildrenSync() != nil else {
                updateValidationStatusForPending()
                Task { [weak self] in
                    _ = await self?.validate()
                }
                return
            }
        }
    }

    func markVisible() {
        if !self.isVisible {
            self.isVisible = true
        }
    }

    func markSubmitted() {
        self.status = .submitted
    }

    private func validateChildrenSync() -> Bool? {
        guard status != .submitted else { return false }

        var childResults: [String: ThomasInputValidator.Result] = [:]
        for (id, child) in self.children {
            if let result = child.input.validator.result, result != .error {
                childResults[id] = result
            } else {
                return nil
            }
        }
        return processChildValidationResults(childResults)
    }

    private func validateChildrenAsync() async -> Bool {
        guard status != .submitted else { return false }

        let start = AirshipDate.shared.now

        let children = self.children
        let result = await withTaskGroup(
            of: (String, ThomasInputValidator.Result).self,
            returning: [String: ThomasInputValidator.Result].self
        ) { group in
            for (id, child) in children {
                let validator = child.input.validator
                group.addTask {
                    let result = await validator.waitResult()
                    return (id, result)
                }
            }

            var results: [String: ThomasInputValidator.Result] = [:]
            for await result in group {
                results[result.0] = result.1
            }

            return results
        }

        // Make sure it took the min time to avoid UI glitches
        let end = AirshipDate.shared.now
        let remaining = Self.minAsyncValidationTime - end.timeIntervalSince(start)
        if (remaining > 0) {
            try? await DefaultAirshipTaskSleeper.shared.sleep(timeInterval: remaining)
        }

        guard !Task.isCancelled else { return false }
        return processChildValidationResults(result)
    }

    private func processChildValidationResults(
        _ results: [String: ThomasInputValidator.Result]
    ) -> Bool {
        self.childResults = results.mapValues { result in
            switch(result) {
            case .valid: .valid
            case .invalid: .invalid
            case .error: .error
            }
        }

        guard !childResults.values.contains(.invalid) else {
            self.status = .invalid(.init(status: childResults))
            return false
        }

        guard !childResults.values.contains(.error) else {
            self.status = .error(.init(status: childResults))

            // If we are in immediate validation mode and we hit an error
            // retry. Backoff is handled in the validators.
            if validationMode == .immediate {
                Task { [weak self] in
                    _ = await self?.validate()
                }
            }

            return false
        }

        self.status = .valid
        return true
    }

    private func updateFormInputEnabled(
        isParentEnabled: Bool?
    ) {
        // Check if we are in a state that allows editing
        // inputs.
        let statusCheck = switch(status) {
        case .valid, .invalid, .error, .pendingValidation: true
        case .submitted: false
        case .validating: validationMode == .immediate
        }

        guard
            self.isEnabled,
            statusCheck,
            (parentFormState?.isFormInputEnabled ?? true)
        else {
            if self.isFormInputEnabled {
                self.isFormInputEnabled = false
            }
            return
        }

        if !self.isFormInputEnabled {
            self.isFormInputEnabled = true
        }
    }

    private func updateValidationStatusForPending() {
        guard status != .pendingValidation else { return }

        guard !childResults.values.contains(.invalid) else {
            self.status = .invalid(.init(status: childResults))
            return
        }

        // Avoid going form invalid -> error after validation
        guard self.status.isError, !childResults.values.contains(.error) else {
            self.status = .error(.init(status: childResults))
            return
        }

        self.status = .pendingValidation
    }
}


fileprivate extension ThomasFormState.FormType {
    func makeFormData(
        identifier: String,
        responseType: String?,
        children: [ThomasFormInput],
        validator: ThomasInputValidator
    ) -> ThomasFormInput {
        return switch(self) {
        case .form:
            ThomasFormInput(
                identifier,
                value: .form(responseType: responseType, children: children),
                validator: validator
            )
        case .nps(let scoreID):
            ThomasFormInput(
                identifier,
                value: .npsForm(responseType: responseType, scoreID: scoreID, children: children),
                validator: validator
            )
        }
    }
}
