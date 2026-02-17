/* Copyright Airship and Contributors */

import Foundation
import Combine

@MainActor
class ThomasState: ObservableObject {
    @Published private(set) var state: AirshipJSON = .object([:])

    private var subscriptions: Set<AnyCancellable> = []

    // Child State Objects
    private let formState: ThomasFormState?
    private let pagerState: PagerState?
    private let mutableState: MutableState?

    private let onStateChange: @Sendable @MainActor (AirshipJSON) -> Void

    // Internal state snapshot that tracks current values
    @MainActor
    private struct StateSnapshot {
        var formStatus: ThomasFormState.Status?
        var formActiveFields: [String: ThomasFormField] = [:]
        var formType: ThomasFormState.FormType?
        var pagerInProgress: Bool?
        var mutableStateValue: AirshipJSON?

        /// Generates the final AirshipJSON based strictly on this snapshot data
        func toAirshipJSON() -> AirshipJSON {
            // Start with the base mutable state object
            var result: [String: AirshipJSON] = mutableStateValue?.object ?? [:]

            // Add $forms
            if let formStatus, let formType {
                result["$forms"] = .object([
                    "current": ThomasFormPayloadGenerator.makeFormStatePayload(
                        status: formStatus,
                        fields: formActiveFields.map { $0.value },
                        formType: formType
                    )
                ])
            }

            // Add $pagers
            if let pagerInProgress {
                result["$pagers"] = .object([
                    "current": .object([
                        "paused": .bool(!pagerInProgress)
                    ])
                ])
            }

            return .object(result)
        }
    }

    private var stateSnapshot: StateSnapshot = StateSnapshot()
    private var lastOutput: AirshipJSON = .object([:])

    init(
        formState: ThomasFormState? = nil,
        pagerState: PagerState? = nil,
        mutableState: MutableState? = nil,
        onStateChange: @escaping @Sendable @MainActor (AirshipJSON) -> Void
    ) {
        self.formState = formState
        self.pagerState = pagerState
        self.mutableState = mutableState
        self.onStateChange = onStateChange

        setupSubscriptions()

        // Initialize snapshot with current values from the passed objects
        self.updateSnapshot(
            formStatus: formState?.status,
            formActiveFields: formState?.activeFields,
            formType: formState?.formType,
            pagerInProgress: pagerState?.inProgress,
            mutableStateValue: mutableState?.state,
        )
    }

    private func setupSubscriptions() {
        formState?.$status.sink { [weak self] in self?.updateSnapshot(formStatus: $0) }.store(in: &subscriptions)
        formState?.$activeFields.sink { [weak self] in self?.updateSnapshot(formActiveFields: $0) }.store(in: &subscriptions)
        pagerState?.$inProgress.sink { [weak self] in self?.updateSnapshot(pagerInProgress: $0) }.store(in: &subscriptions)
        mutableState?.$state.sink { [weak self] in self?.updateSnapshot(mutableStateValue: $0) }.store(in: &subscriptions)
    }

    private func updateSnapshot(
        formStatus: ThomasFormState.Status? = nil,
        formActiveFields: [String: ThomasFormField]? = nil,
        formType: ThomasFormState.FormType? = nil,
        pagerInProgress: Bool? = nil,
        mutableStateValue: AirshipJSON? = nil,
    ) {
        // Update the snapshot with provided values
        if let val = formStatus { stateSnapshot.formStatus = val }
        if let val = formActiveFields { stateSnapshot.formActiveFields = val }
        if let val = formType { stateSnapshot.formType = val }
        if let val = pagerInProgress { stateSnapshot.pagerInProgress = val }
        if let val = mutableStateValue { stateSnapshot.mutableStateValue = val }

        // Compute new output directly from the snapshot
        let newOutput = stateSnapshot.toAirshipJSON()

        // Only update if output actually changed
        if newOutput != lastOutput {
            AirshipLogger.trace("State updated: \(newOutput.prettyJSONString) old: \(lastOutput.prettyJSONString)")
            self.state = newOutput
            self.lastOutput = newOutput
            self.onStateChange(newOutput)
        }
    }

    func with(
        formState: ThomasFormState? = nil,
        pagerState: PagerState? = nil,
        mutableState: MutableState? = nil,
    ) -> ThomasState {
        let newFormState = formState ?? self.formState
        let newPagerState = pagerState ?? self.pagerState
        let newMutableState = mutableState ?? self.mutableState

        // Return self if nothing changed to avoid redundant copies
        if newFormState === self.formState,
           newPagerState === self.pagerState,
           newMutableState === self.mutableState {
            return self
        }

        return .init(
            formState: newFormState,
            pagerState: newPagerState,
            mutableState: newMutableState,
            onStateChange: self.onStateChange
        )
    }

    func processStateActions(
        _ stateActions: [ThomasStateAction],
        formFieldValue: ThomasFormField.Value? = nil
    ) {
        stateActions.forEach { action in
            switch action {
            case .setState(let details):
                self.mutableState?.set(key: details.key, value: details.value, ttl: details.ttl)
            case .clearState:
                self.mutableState?.clearState()
            case .formValue(let details):
                self.mutableState?.set(key: details.key, value: formFieldValue?.stateFormValue)
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

        fileprivate func set(key: String, value: AirshipJSON?, ttl: TimeInterval? = nil) {
            if let ttl = ttl {
                let mutation = TempMutation(id: UUID().uuidString, key: key, value: value)
                tempMutations[key] = mutation
                appliedState[key] = nil
                updateState()

                Task { [weak self] in
                    try? await self?.taskSleeper.sleep(timeInterval: ttl)
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

fileprivate extension ThomasFormField.Value {
    var stateFormValue: AirshipJSON? {
        switch(self) {
        case .toggle(let value): return .bool(value)
        case .multipleCheckbox(let value): return .array(Array(value))
        case .radio(let value): return value
        case .sms(let value), .email(let value), .text(let value):
            guard let value else { return nil }
            return .string(value)
        case .score(let value): return value
        case .form, .npsForm: return nil
        }
    }
}

fileprivate extension AirshipJSON {
    var prettyJSONString: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        return (try? self.toString(encoder: encoder)) ?? "Invalid JSON"
    }
}

@MainActor
final class ScopedStateCache: ObservableObject {
    private var cachedState: ThomasState?
    
    private let updateSubject = PassthroughSubject<any Codable, Never>()
    private var subscription: AnyCancellable?
    private var pendingUpdate: SnapshotType? = nil

    func getOrCreate(_ createState: () -> ThomasState) -> ThomasState {
        if let cached = cachedState { return cached }
        let scoped = createState()
        
        if let pendingUpdate {
            scoped.restorePersistentState(pendingUpdate)
            self.pendingUpdate = nil
        }
        
        cachedState = scoped
        rebroadcastUpdates(scoped)
        return scoped
    }

    func invalidate() {
        cachedState = nil
        rebroadcastUpdates(nil)
        pendingUpdate = nil
    }
    
    private func rebroadcastUpdates(_ state: ThomasState?) {
        guard let state else {
            subscription?.cancel()
            subscription = nil
            updateSubject.send(ThomasState.PersistentState(
                formState: nil,
                pagerState: nil,
                mutableState: nil)
            )
            return
        }
        
        subscription = state.updates
            .sink { [weak self] update in
                self?.updateSubject.send(update)
            }
    }
}

//MARK: - ThomasStateProvider
extension ThomasState.MutableState: ThomasStateProvider {
    typealias StateSnapshot = [String: AirshipJSON]
    
    var updates: AnyPublisher<any Codable, Never> {
        return $state.removeDuplicates().map(\.self).eraseToAnyPublisher()
    }
    
    func persistentStateSnapshot() -> StateSnapshot {
        return self.appliedState
    }
    
    func restorePersistentState(_ state: [String: AirshipJSON]) {
        self.appliedState = state
        DispatchQueue.main.async { self.updateState() }
    }
}

extension ThomasState: ThomasStateProvider {
    typealias SnapshotType = PersistentState
    
    struct PersistentState: Codable {
        let formState: ThomasFormState.SnapshotType?
        let pagerState: PagerState.SnapshotType?
        let mutableState: MutableState.SnapshotType?
    }
    
    var updates: AnyPublisher<any Codable, Never> {
        return $state.removeDuplicates().map(\.self).eraseToAnyPublisher()
    }
    
    func persistentStateSnapshot() -> PersistentState {
        return PersistentState(
            formState: formState?.persistentStateSnapshot(),
            pagerState: pagerState?.persistentStateSnapshot(),
            mutableState: mutableState?.persistentStateSnapshot()
        )
    }
    
    func restorePersistentState(_ state: PersistentState) {
        if let form = state.formState {
            self.formState?.restorePersistentState(form)
        }
        
        if let pager = state.pagerState {
            self.pagerState?.restorePersistentState(pager)
        }
        
        if let mutable = state.mutableState {
            self.mutableState?.restorePersistentState(mutable)
        }
    }
}

extension ScopedStateCache: ThomasStateProvider {
    typealias SnapshotType = ThomasState.PersistentState
    
    var updates: AnyPublisher<any Codable, Never> {
        return updateSubject
            .compactMap({ [weak self] _ in self?.makeSnapshot(self?.cachedState) })
            .eraseToAnyPublisher()
    }
    
    func persistentStateSnapshot() -> SnapshotType {
        return makeSnapshot(cachedState)
    }
    
    func restorePersistentState(_ state: SnapshotType) {
        if let thomasState = cachedState {
            thomasState.restorePersistentState(state)
        } else {
            pendingUpdate = state
        }
    }
    
    private func makeSnapshot(_ state: ThomasState?) -> ThomasState.PersistentState {
        return state?.persistentStateSnapshot() ?? ThomasState.PersistentState(
            formState: nil,
            pagerState: nil,
            mutableState: nil
        )
    }
}
