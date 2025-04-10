/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Combine

@MainActor
final class ValidatableHelper : ObservableObject {

    enum ValidationAction: Equatable, Hashable {
        case edit
        case error
        case valid
        case none
    }

    private var subscriptionState: [String: State] = [:]

    private final class State {
        var lastValue: (any Equatable)?
        var isInitialValue: Bool
        var subscription: AnyCancellable?
        var lastAction: ValidationAction?

        init(isInitialValue: Bool, lastValue: (any Equatable)? = nil, subscription: AnyCancellable? = nil) {
            self.isInitialValue = isInitialValue
            self.lastValue = lastValue
            self.subscription = subscription
        }
    }

    func subscribe<T: Equatable>(
        forIdentifier identifier: String,
        formState: ThomasFormState,
        initialValue: T?,
        valueUpdates: Published<T>.Publisher,
        validatables: ThomasValidationInfo,
        onStateActions: @escaping @MainActor ([ThomasStateAction]) -> Void
    ) {
        let state: State = subscriptionState[identifier] ?? State(
            isInitialValue: true,
            lastValue: initialValue
        )

        subscriptionState[identifier] = state
        state.subscription?.cancel()

        state.subscription = Publishers.CombineLatest(
            formState.$status,
            valueUpdates
        )
        .receive(on: RunLoop.main)
        .map { (status, value) -> ValidationAction in
            let fieldStatus = formState.lastFieldStatus(
                identifier: identifier
            )

            var didEdit = false
            if value != state.lastValue as? Published<T>.Publisher.Output {
                state.lastValue = value
                didEdit = true
                state.isInitialValue = false
            }

            guard let fieldStatus else {
                return didEdit ? .edit : .none
            }

            switch (status) {
            case .valid, .error, .invalid:
                switch(fieldStatus) {
                case .valid: return .valid
                case .invalid:
                    return if !state.isInitialValue || formState.validationMode == .onDemand {
                        .error
                    } else {
                        .none
                    }
                case .pending: return .edit
                case .error: return .none
                }

            default: return didEdit ? .edit : .none
            }
        }
        .filter {
            $0 != state.lastAction
        }
        .sink { action in
            state.lastAction = action

            let actions: [ThomasStateAction]? = switch(action) {
            case .edit:
                validatables.onEdit?.stateActions
            case .error:
                validatables.onError?.stateActions
            case .valid:
                validatables.onValid?.stateActions
            case .none:
                nil
            }

            guard let actions else { return }
            onStateActions(actions)
        }
    }
}
