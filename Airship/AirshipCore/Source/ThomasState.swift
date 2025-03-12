/* Copyright Airship and Contributors */

import Foundation
import Combine

@MainActor
class ThomasState: ObservableObject {
    @Published private(set) var state: AirshipJSON

    private var subscriptions: Set<AnyCancellable> = []

    private let formState: ThomasFormState
    private let mutableState: MutableState

    func copy(
        formState: ThomasFormState? = nil,
        mutableState: MutableState? = nil
    ) -> ThomasState {
        return .init(
            formState: formState ?? self.formState,
            mutableState: mutableState ?? self.mutableState
        )
    }
    

    init(formState: ThomasFormState, mutableState: MutableState = .init()) {
        self.formState = formState
        self.mutableState = mutableState

        self.state = ThomasStatePayload(
            formStatus: formState.status,
            formData: formState.data.innerData,
            mutableState: mutableState.state
        ).json

        Publishers.CombineLatest3(formState.$status, formState.$data, mutableState.$state)
            .map { formStatus, formData, mutableState in
                ThomasStatePayload(
                    formStatus: formStatus,
                    formData: formData.innerData,
                    mutableState: mutableState
                ).json
            }
            .removeDuplicates()
            .sink { [weak self] state in
                self?.state = state
            }
            .store(in: &subscriptions)
    }

    func processStateActions(
        _ stateActions: [ThomasStateAction],
        formInput: ThomasFormInput? = nil
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
                if let formInput {
                    do {
                        self.mutableState.set(
                            key: details.key,
                            value: try AirshipJSON.wrap(formInput.value)
                        )
                    } catch {
                        AirshipLogger.warn("Failed to wrap form value \(error)")
                    }
                } else {
                    AirshipLogger.warn("Unable to handle state actions for form value")
                }
            }
        }
    }

    @MainActor
    class MutableState: ObservableObject {
        @Published private(set) var state: AirshipJSON = .object([:])
        private var appliedState: [String: AirshipJSON] = [:]
        private var tempMutations: [String: TempMutation] = [:]

        private let taskSleeper: any AirshipTaskSleeper

        init(
            taskSleeper: any AirshipTaskSleeper = DefaultAirshipTaskSleeper.shared
        ) {
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

fileprivate extension ThomasFormInput {
    // For current form data we need the inner form values with the
    // form id.
    var innerData: AirshipJSON {
        do {
            return try AirshipJSON.wrap(self.getData())
        } catch {
            AirshipLogger.error("Failed to wrap form data \(error)")
            return .null
        }
    }
}



fileprivate struct ThomasStatePayload: Encodable, Sendable, Equatable {
    private let state: AirshipJSON?
    private let forms: FormsHolder

    @MainActor
    init(
        formStatus: ThomasFormStatus,
        formData: AirshipJSON,
        mutableState: AirshipJSON
    ) {
        self.state = mutableState
        self.forms = FormsHolder(
            forms: Forms(
                current: Form(
                    status: formStatus,
                    data: formData
                )
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
        let current: Form
    }

    struct Form: Encodable, Sendable, Equatable {
        let status: ThomasFormStatus
        let data: AirshipJSON
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
