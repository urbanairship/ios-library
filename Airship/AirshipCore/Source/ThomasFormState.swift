/* Copyright Airship and Contributors */

import Foundation
import Combine

@MainActor
class ThomasFormDataCollector: ObservableObject {
    let formState: ThomasFormState?
    let pagerState: PagerState?

    private var subscriptions: Set<AnyCancellable> = Set()

    init(formState: ThomasFormState? = nil, pagerState: PagerState? = nil) {
        self.formState = formState
        self.pagerState = pagerState

        pagerState?.$currentPageId
            .removeDuplicates()
            // Using this over RunLoop.main as it seems to prevent
            // some unwanted UI jank with form validation enablement
            .receive(on: DispatchQueue.main)
            .sink { [weak formState] _ in
                formState?.updateData()
            }
            .store(in: &subscriptions)
    }

    func copy(
        formState: ThomasFormState? = nil,
        pagerState: PagerState? = nil
    ) -> ThomasFormDataCollector {
        return .init(
            formState: formState ?? self.formState,
            pagerState: pagerState ?? self.pagerState
        )
    }

    func updateFormInput(
        _ data: ThomasFormInput,
        validator: ThomasInputValidator,
        pageID: String?
    ) {
        formState?.updateFormInput(data, validator: validator) { [weak pagerState] in
            guard let pageID else { return true }
            guard let pagerState else { return false }

            let pageIDs = pagerState.pageItems.map { $0.id }

            // Make sure the page ID is within the current history
            guard
                let current = pagerState.currentPageId,
                let currentIndex = pageIDs.lastIndex(of: current),
                let lastIndex = pageIDs.lastIndex(of: pageID),
                lastIndex <= currentIndex
            else {
                return false
            }
            return true
        }
    }
}


@MainActor
class ThomasFormState: ObservableObject {

    // Minimum time to wait when doing async validation if
    // all the form results are yet to be ready onValidate
    private static let minAsyncValidationTime: TimeInterval = 1.0

    enum FormType: Sendable {
        case nps(String)
        case form
    }

    @Published
    var status: ThomasFormStatus = .pendingValidation {
        didSet {
            updateFormInputEnabled(
                isParentEnabled: self.parentFormState?.isFormInputEnabled
            )
        }
    }

    @Published
    private(set) var data: ThomasFormInput

    func child(identifier: String) -> ThomasFormInput? {
        self.children[identifier]?.field
    }

    @Published
    private(set) var isVisible: Bool = false

    @Published
    var isEnabled: Bool = true {
        didSet {
            updateFormInputEnabled(
                isParentEnabled: self.parentFormState?.isFormInputEnabled
            )
        }
    }


    @Published
    var isFormInputEnabled: Bool = true

    // On submit block
    var onSubmit: (@Sendable @MainActor (ThomasFormState, LayoutState) throws -> Void)?

    let validationMode: ThomasFormValidationMode
    let identifier: String
    let formType: FormType
    let formResponseType: String?

    @MainActor
    private struct Child {
        var field: ThomasFormInput
        var validator: ThomasInputValidator
        var predicate: (@MainActor @Sendable () -> Bool)?
    }

    private var children: [String: Child] = [:]
    private var subscriptions: Set<AnyCancellable> = Set()
    private var validationTask: Task<Bool, Never>?
    private var childResults: [String: ThomasFormStatus.ChildValidationStatus] = [:]
    private var parentFormState: ThomasFormState?

    init(
        identifier: String,
        formType: FormType,
        formResponseType: String?,
        validationMode: ThomasFormValidationMode,
        parentFormState: ThomasFormState? = nil
    ) {
        self.identifier = identifier
        self.formType = formType
        self.formResponseType = formResponseType
        self.validationMode = validationMode
        self.parentFormState = parentFormState

        self.data = formType.makeFormData(
            identifier: identifier,
            responseType: formResponseType,
            children: []
        )

        parentFormState?.$isFormInputEnabled.sink { [weak self] parentEnabled in
            self?.updateFormInputEnabled(isParentEnabled: parentEnabled)
        }.store(in: &subscriptions)
    }

    func markVisible() {
        guard !self.isVisible else { return }
        parentFormState?.markVisible()
        self.isVisible = true
    }

    func validate() async -> Bool {
        await self.validateChildren()
    }

    private func markSubmitted() {
        self.status = .submitted
    }

    func submit(layoutState: LayoutState) async throws {
        guard let onSubmit else {
            throw AirshipErrors.error("onSubmit block missing")
        }

        guard self.status != .submitted else {
            throw AirshipErrors.error("Form already submitted")
        }

        guard await self.validate() else {
            throw AirshipErrors.error("Form not valid")
        }

        try onSubmit(self, layoutState)
    }

    private func validateChildren() async -> Bool {
        guard self.status != .submitted else { return true }

        self.updateData()
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

    fileprivate func updateData() {
        guard self.status != .submitted else { return }

        let filtered = filteredChildren()

        let data = formType.makeFormData(
            identifier: identifier,
            responseType: formResponseType,
            children: Array(filtered.values.map { $0.field })
        )

        guard data != self.data else { return }

        self.data = data

        switch(self.status) {
        case .error, .valid, .invalid, .pendingValidation:
            updateValidationStatusForPending(filtered)
        case .validating:
            validationTask?.cancel()
            self.status = .pendingValidation
        case .submitted:
            break
        }
    }

    private func filteredChildren() -> [String: Child] {
        return self.children.filter { _, value in
            value.predicate?() ?? true
        }
    }

    fileprivate func updateFormInput(
        _ field: ThomasFormInput,
        validator: ThomasInputValidator,
        predicate: (@Sendable @MainActor () -> Bool)? = nil
    ) {
        guard self.status != .submitted else { return }
        validationTask?.cancel()

        // Remove the invalid flag if we know the incoming value is not valid
        // This helps prevent removing the invalid status for things like checkbox
        // controllers if they have yet to select the right number of items.
        if childResults[field.identifier] != .invalid || validator.result != .invalid {
            childResults[field.identifier] = .pendingValidation
        }

        self.children[field.identifier] = Child(field: field, validator: validator, predicate: predicate)

        self.updateData()

        if validationMode == .immediate, validateChildrenSync() == nil {
            Task { [weak self] in
                _ = await self?.validateChildren()
            }
        }
    }

    private func validateChildrenSync() -> Bool? {
        guard status != .submitted else { return false }

        var childResults: [String: ThomasInputValidator.Result] = [:]
        for (id, child) in self.filteredChildren() {
            if let result = child.validator.result, result != .error {
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

        let children = self.filteredChildren()
        let result = await withTaskGroup(
            of: (String, ThomasInputValidator.Result).self,
            returning: [String: ThomasInputValidator.Result].self
        ) { group in
            for (id, child) in children {
                let validator = child.validator
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
        let newResults: [String: ThomasFormStatus.ChildValidationStatus] = results.mapValues { result in
            switch(result) {
            case .valid: .valid
            case .invalid: .invalid
            case .error: .error
            }
        }
        self.childResults.merge(newResults) { _, new in new }

        guard !newResults.values.contains(.invalid) else {
            self.status = .invalid(.init(status: childResults))
            return false
        }

        guard !newResults.values.contains(.error) else {
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

    private func updateFormInputEnabled(isParentEnabled: Bool?) {
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
            isParentEnabled ?? true
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

    private func updateValidationStatusForPending(_ filteredChildren: [String: Child]) {
        let filteredIDs = Set(filteredChildren.map { $0.key })

        let filteredResults = self.childResults.filter {
            filteredIDs.contains($0.key)
        }

        guard !filteredResults.values.contains(.invalid) else {
            self.status = .invalid(.init(status: childResults))
            return
        }

        // Avoid going form invalid -> error after validation
        guard self.status.isError, filteredResults.values.contains(.error) else {
            if status != .pendingValidation {
                self.status = .pendingValidation
            }
            return
        }

        self.status = .error(.init(status: childResults))
    }
}

fileprivate extension ThomasFormState.FormType {
    func makeFormData(
        identifier: String,
        responseType: String?,
        children: [ThomasFormInput]
    ) -> ThomasFormInput {
        return switch(self) {
        case .form:
            ThomasFormInput(
                identifier,
                value: .form(responseType: responseType, children: children)
            )
        case .nps(let scoreID):
            ThomasFormInput(
                identifier,
                value: .npsForm(responseType: responseType, scoreID: scoreID, children: children)
            )
        }
    }
}
