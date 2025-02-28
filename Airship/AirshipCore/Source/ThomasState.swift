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
            mutableState: .object(mutableState.state)
        ).json

        Publishers.CombineLatest3(formState.$status, formState.$data, mutableState.$state)
            .map { formStatus, formData, mutableState in
                ThomasStatePayload(
                    formStatus: formStatus,
                    formData: formData.innerData,
                    mutableState: .object(mutableState)
                ).json
            }
            .removeDuplicates()
            .sink { [weak self] state in
                self?.state = state
            }
            .store(in: &subscriptions)
    }

    func clearState() {
        mutableState.clearState()
    }

    func updateState(key: String, value: AirshipJSON?) {
        mutableState.updateState(key: key, value: value)
    }

    func processStateActions(
        _ stateActions: [ThomasStateAction],
        formInput: ThomasFormInput? = nil
    ) {
        stateActions.forEach { action in
            switch action {
            case .setState(let details):
                updateState(
                    key: details.key,
                    value: details.value
                )
            case .clearState:
                clearState()
            case .formValue(let details):
                if let formInput {
                    do {
                        updateState(key: details.key, value: try AirshipJSON.wrap(formInput.value))
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
        @Published var state: [String: AirshipJSON] = [:]

        fileprivate func clearState() {
            guard !state.isEmpty else {
                return
            }

            objectWillChange.send()
            state.removeAll()
        }

        fileprivate func updateState(key: String, value: AirshipJSON?) {
            objectWillChange.send()
            state[key] = value
        }
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
        try state?.encode(to: encoder)
        try forms.encode(to: encoder)
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
