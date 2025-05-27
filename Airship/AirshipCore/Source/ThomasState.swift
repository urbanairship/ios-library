/* Copyright Airship and Contributors */

import Foundation
import Combine

@MainActor
class ThomasState: ObservableObject {
    @Published private(set) var state: AirshipJSON

    private var subscriptions: Set<AnyCancellable> = []

    private let formState: ThomasFormState
    private let mutableState: MutableState
    private let onStateChange: @Sendable @MainActor (AirshipJSON) -> Void

    func copy(
        formState: ThomasFormState? = nil,
        mutableState: MutableState? = nil
    ) -> ThomasState {
        return .init(
            formState: formState ?? self.formState,
            mutableState: mutableState ?? self.mutableState,
            onStateChange: self.onStateChange
        )
    }

    init(
        formState: ThomasFormState,
        mutableState: MutableState = .init(),
        onStateChange: @escaping @Sendable @MainActor (AirshipJSON) -> Void
    ) {
        self.formState = formState
        self.mutableState = mutableState
        self.onStateChange = onStateChange

        self.state = ThomasStatePayload(
            formData: ThomasFormPayloadGenerator.makeFormStatePayload(
                status: formState.status,
                fields: formState.activeFields.map { $0.value },
                formType: formState.formType
            ),
            mutableState: mutableState.state
        ).json

        Publishers.CombineLatest3(formState.$status, formState.$activeFields, mutableState.$state)
            .map { formStatus, activeFields, mutableState in
                ThomasStatePayload(
                    formData: ThomasFormPayloadGenerator.makeFormStatePayload(
                        status: formStatus,
                        fields: activeFields.map { $0.value },
                        formType: formState.formType
                    ),
                    mutableState: mutableState
                ).json
            }
            .removeDuplicates()
            .sink { [weak self] state in
                self?.state = state
                AirshipLogger.trace("State updated: \(state.prettyJSONString)")
                self?.onStateChange(state)
            }
            .store(in: &subscriptions)
    }

    func processStateActions(
        _ stateActions: [ThomasStateAction],
        formFieldValue: ThomasFormField.Value? = nil
    ) {
        stateActions.forEach { action in
            switch action {
            case .setState(let details):
                self.mutableState.set(
                    key: details.key,
                    value: details.value,
                    ttl: details.ttl
                )
            case .clearState:
                self.mutableState.clearState()
            case .formValue(let details):
                self.mutableState.set(
                    key: details.key,
                    value: formFieldValue?.stateFormValue
                )
            }
        }
    }

    @MainActor
    class MutableState: ObservableObject {
        @Published private(set) var state: AirshipJSON
        private var appliedState: [String: AirshipJSON] = [:]
        private var tempMutations: [String: TempMutation] = [:]

        private let taskSleeper: any AirshipTaskSleeper

        init(
            inititalState: AirshipJSON? = nil,
            taskSleeper: any AirshipTaskSleeper = DefaultAirshipTaskSleeper.shared
        ) {
            self.state = inititalState ?? .object([:])
            self.taskSleeper = taskSleeper
        }
            
        fileprivate func clearState() {
            tempMutations.removeAll()
            appliedState.removeAll()
            updateState()
        }

        private func updateState() {
            var state = self.appliedState
            tempMutations.forEach { key, mutation in
                state[key] = mutation.value
            }
            self.state = .object(state)
        }

        private func removeTempMutation(_ mutation: TempMutation) {
            guard tempMutations[mutation.key] == mutation else { return }
            tempMutations[mutation.key] = nil
            self.updateState()
        }

        fileprivate func set(
            key: String,
            value: AirshipJSON?,
            ttl: TimeInterval? = nil
        ) {
            if let ttl = ttl {
                let mutation = TempMutation(
                    id: UUID().uuidString,
                    key: key,
                    value: value
                )

                tempMutations[key] = mutation
                appliedState[key] = nil
                updateState()

                Task { [weak self] in
                    do {
                        try await self?.taskSleeper.sleep(timeInterval: ttl)
                    } catch {
                        AirshipLogger.warn("Failed to sleep for ttl: \(error)")
                    }
                    self?.removeTempMutation(mutation)
                }
            } else {
                tempMutations[key] = nil
                appliedState[key] = value
                updateState()
            }
        }
    }

    fileprivate struct TempMutation: Sendable, Equatable, Hashable {
        let id: String
        let key: String
        let value: AirshipJSON?
    }
}

fileprivate struct ThomasStatePayload: Encodable, Sendable, Equatable {
    private let state: AirshipJSON?
    private let forms: FormsHolder

    @MainActor
    init(
        formData: AirshipJSON,
        mutableState: AirshipJSON
    ) {
        self.state = mutableState
        self.forms = FormsHolder(
            forms: Forms(
                current: formData
            )
        )
    }

    func encode(to encoder: any Encoder) throws {
        do {
            try state?.encode(to: encoder)
            try forms.encode(to: encoder)
        } catch {
            throw error
        }
    }

    struct FormsHolder: Encodable, Sendable, Equatable {
        let forms: Forms

        enum CodingKeys: String, CodingKey {
            case forms = "$forms"
        }
    }

    struct Forms: Encodable, Sendable, Equatable {
        let current: AirshipJSON
    }

    var json: AirshipJSON {
        do {
            return try AirshipJSON.wrap(self)
        } catch {
            AirshipLogger.error("Failed to wrap state \(error)")
            return .null
        }
    }
}


fileprivate extension ThomasFormField.Value {
    var stateFormValue: AirshipJSON? {
        switch(self) {
        case .toggle(let value):
            return .bool(value)
        case .multipleCheckbox(let value):
            return .array(Array(value))
        case .radio(let value):
            return value
        case .sms(let value), .email(let value), .text(let value):
            guard let value else { return nil }
            return .string(value)
        case .score(let value):
            return value
        case .form, .npsForm:
            // not supported
            return nil
        }

    }
}

fileprivate extension AirshipJSON {
    var prettyJSONString: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        do {
            return try self.toString(encoder: encoder)
        } catch {
            return "Error: \(error)"
        }
    }
}
