/* Copyright Airship and Contributors */

import Foundation
import Combine

@MainActor
class ThomasFormState: ObservableObject {

    /// Represents the possible statuses of a form during its lifecycle.
    enum Status: String, Equatable, Sendable, Hashable {
        /// The form is valid and all its fields are correctly filled out.
        case valid

        /// The form is invalid, possibly due to incorrect or missing information.
        case invalid

        /// An error occurred during form validation or submission.
        case error

        /// The form is currently being validated.
        case validating

        /// The form is awaiting validation to be processed.
        case pendingValidation = "pending_validation"

        /// The form has been submitted.
        case submitted
    }

    enum FormType: Sendable, Equatable {
        case nps(String)
        case form
    }

    @MainActor
    private struct Child {
        var field: ThomasFormField
        var watchTask: Task<Void, Never>
        var predicate: (@MainActor @Sendable () -> Bool)?
    }

    // Minimum time to wait when doing async validation if
    // all the form results are yet to be ready onValidate
    private static let minAsyncValidationTime: TimeInterval = 1.0

    @Published
    private(set) var status: Status {
        didSet {
            updateFormInputEnabled(
                isParentEnabled: self.parentFormState?.isFormInputEnabled
            )
        }
    }

    @Published
    private(set) var activeFields: [String: ThomasFormField] = [:]

    @Published
    private(set) var isVisible: Bool = false

    @Published
    private(set) var isFormInputEnabled: Bool = true

    @Published
    var isEnabled: Bool = true {
        didSet {
            updateFormInputEnabled(
                isParentEnabled: self.parentFormState?.isFormInputEnabled
            )
        }
    }

    // On submit block
    var onSubmit: (@Sendable @MainActor (String, ThomasFormField.Result, LayoutState) throws -> Void)?

    let identifier: String
    let formType: FormType
    let formResponseType: String?
    let validationMode: ThomasFormValidationMode

    private var children: [Child] = []
    private var subscriptions: Set<AnyCancellable> = Set()
    private var processTask: Task<Bool, Never>?
    private var lastChildStatus: [String: ThomasFormField.Status] = [:]
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
        self.status = if validationMode == .immediate {
            .invalid
        } else {
            .pendingValidation
        }
        
        parentFormState?.$isFormInputEnabled.sink { [weak self] parentEnabled in
            self?.updateFormInputEnabled(isParentEnabled: parentEnabled)
        }.store(in: &subscriptions)
    }

    func field(identifier: String) -> ThomasFormField? {
        return self.children.first { child in
            child.field.identifier == identifier
        }?.field
    }

    func lastFieldStatus(identifier: String) -> ThomasFormField.Status? {
        return self.lastChildStatus[identifier]
    }

    func markVisible() {
        guard !self.isVisible else { return }
        parentFormState?.markVisible()
        self.isVisible = true
    }

    func validate() async -> Bool {
        return await self.processChildren(children: self.filteredChildren())
    }

    func submit(layoutState: LayoutState) async throws {
        guard self.status != .submitted else {
            throw AirshipErrors.error("Form already submitted")
        }

        guard let onSubmit else {
            throw AirshipErrors.error("onSubmit block missing")
        }

        // Grab a snapshot of the children since this is a async
        // task so data might change while we process and submit
        let children = self.filteredChildren()
        guard await self.processChildren(children: children) else {
            throw AirshipErrors.error("Form not valid")
        }

        var attributesResult: [ThomasFormField.Attribute] = []
        var channelsResult: [ThomasFormField.Channel] = []
        var resultMap: [String: ThomasFormField.Value] = [:]

        try children.forEach {
            if case let .valid(result) = $0.field.status {
                resultMap[$0.field.identifier] = result.value
                if let channels = result.channels {
                    channelsResult.append(contentsOf: channels)
                }

                if let attributes = result.attributes {
                    attributesResult.append(contentsOf: attributes)
                }
            } else {
                throw AirshipErrors.error("Form is not valid")
            }
        }

        guard !resultMap.isEmpty else {
            throw AirshipErrors.error("Form has no data")
        }

        let formResult = ThomasFormField.Result(
            value: self.formType.makeField(
                responseType: self.formResponseType,
                children: resultMap
            ),
            channels: channelsResult,
            attributes: attributesResult
        )

        try onSubmit(self.identifier, formResult, layoutState)
        updateStatus(.submitted)
    }

    func dataChanged() {
        guard self.status != .submitted else { return }

        let children = self.filteredChildren()
        self.updateActiveFields(children: children)

        switch(self.status) {
        case .error, .valid, .invalid, .pendingValidation:
            let childStatuses = children.compactMap { lastChildStatus[$0.field.identifier] }

            switch (self.validationMode) {
            case .onDemand:
                // On demand we want to leave the child in an invalid or error state
                // until the next validation request.
                if childStatuses.contains(.invalid) {
                    self.updateStatus(.invalid)
                } else if status == .error, !childStatuses.contains(.error) {
                    self.updateStatus(.pendingValidation)
                } else if childStatuses.contains(.pending) {
                    self.updateStatus(.pendingValidation)
                } else if status != .pendingValidation {
                    if childStatuses.contains(.error) {
                        self.updateStatus(.error)
                    } else {
                        self.updateStatus(.valid)
                    }
                }
            case .immediate:
                // Immediate we want to go to pending if any pending since
                // and schedule a task to validate
                if childStatuses.contains(.pending) {
                    self.updateStatus(.pendingValidation)
                } else if childStatuses.contains(.invalid) {
                    self.updateStatus(.invalid)
                } else if status == .error, !childStatuses.contains(.error) {
                    self.updateStatus(.pendingValidation)
                } else if status != .pendingValidation {
                    if childStatuses.contains(.error) {
                        self.updateStatus(.error)
                    } else {
                        self.updateStatus(.valid)
                    }
                }
            }

        case .submitted, .validating:
            break
        }

        guard validationMode == .immediate else { return }

        if status != .valid, status != .invalid {
            Task { [weak self] in
                await self?.validate()
            }
        }
    }

    func updateField(
        _ field: ThomasFormField,
        predicate: (@Sendable @MainActor () -> Bool)? = nil
    ) {
        guard self.status != .submitted else { return }

        self.processTask?.cancel()

        if self.status == .validating {
            updateStatus(.pendingValidation)
        }

        // If we are in onDemand mode and the old value is invalid, make sure
        // the incoming value is not also invalid. This helps prevent removing
        // the invalid status until we know its valid or pending.
        if self.validationMode == .onDemand, lastChildStatus[field.identifier] == .invalid {
            if field.status != .invalid {
                lastChildStatus[field.identifier] = .pending
            }
        } else {
            lastChildStatus[field.identifier] = .pending
        }

        self.children.removeAll { child in
            if child.field.identifier == field.identifier {
                child.watchTask.cancel()
                return true
            }
            return false
        }

        if self.activeFields[field.identifier] != nil  {
            self.activeFields[field.identifier] = field
        }
        
        self.children.append(
            Child(
                field: field,
                watchTask: Task { [weak self, field] in
                    for await _ in field.statusUpdates {
                        guard !Task.isCancelled else { return }
                        self?.updateActiveFields()
                    }
                },
                predicate: predicate
            )
        )

        self.dataChanged()
    }

    private func processChildren(children: [Child]) async -> Bool  {
        guard self.status != .submitted else { return false }
        self.processTask?.cancel()

        let needsAsync = children.contains { child in
            child.field.status == .error || child.field.status == .pending
        }

        updateStatus(.validating)
        let task = Task { [weak self] in

            guard needsAsync else {
                return self?.processingFinished(children: children) ?? false
            }

            let start = AirshipDate.shared.now
            await withTaskGroup(of: Void.self) { group in
                for child in children {
                    group.addTask {
                        await child.field.process(retryErrors: true)
                    }
                }
                await group.waitForAll()
            }

            // Make sure it took the min time to avoid UI glitches
            let end = AirshipDate.shared.now
            let remaining = Self.minAsyncValidationTime - end.timeIntervalSince(start)
            if (remaining > 0) {
                try? await DefaultAirshipTaskSleeper.shared.sleep(timeInterval: remaining)
            }

            guard !Task.isCancelled else { return false }
            return self?.processingFinished(children: children) ?? false
        }

        self.processTask = task
        return await task.value
    }

    private func updateStatus(_ status: Status) {
        guard self.status != .submitted, self.status != status else {
            return
        }
        print("updating status \(self.status) => \(status)")
        self.status = status
    }

    private func updateActiveFields(children: [Child]) {
        let currentKeys = Set(self.activeFields.values.map { $0.identifier })
        let incomingKeys = Set(children.map { $0.field.identifier })
        guard currentKeys != incomingKeys else { return }

        self.activeFields = Dictionary(
            uniqueKeysWithValues: children.map {
                ($0.field.identifier, $0.field)
            }
        )
    }

    private func updateActiveFields() {
        self.updateActiveFields(children: self.filteredChildren())
    }

    private func filteredChildren() -> [Child] {
        return self.children.filter { value in
            value.predicate?() ?? true
        }
    }

    private func processingFinished(children: [Child]) -> Bool {
        defer {
            self.dataChanged()
        }

        var containsError: Bool = false
        var containsInvalid: Bool = false
        var containsValid: Bool = false

        for child in children {
            let status = child.field.status

            if status == .error {
                containsError = true
            }

            if status == .invalid {
                containsInvalid = true
            }

            if status.isValid {
                containsValid = true
            }

            lastChildStatus[child.field.identifier] = status
        }

        if containsInvalid {
            updateStatus(.invalid)
            return false
        } else if containsError {
            updateStatus(.error)

            // If we are in immediate validation mode and we hit an error we need
            // to retry right away since the submit button to update wont be available
            // to retrigger a retry.
            if validationMode == .immediate {
                Task { [weak self] in
                    _ = await self?.validate()
                }
            }
            return false
        } else if containsValid {
            updateStatus(.valid)
            return true
        } else {
            updateStatus(.invalid)
            return false
        }
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
}

fileprivate extension ThomasFormState.FormType {
    @MainActor
    func makeField(
        responseType: String?,
        children: [String: ThomasFormField.Value]
    ) -> ThomasFormField.Value {
        return switch(self) {
        case .form:
                .form(responseType: responseType, children: children)
        case .nps(let scoreID):
                .npsForm(responseType: responseType, scoreID: scoreID, children: children)
        }
    }
}

