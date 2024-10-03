/* Copyright Airship and Contributors */

import Foundation

@MainActor
class ViewState: ObservableObject {
    @Published var state: [String: Any] = [:]

    func clearState() {
        guard !state.isEmpty else {
            return
        }

        objectWillChange.send()
        state.removeAll()
    }

    func updateState(key: String, value: Any?) {
        objectWillChange.send()
        state[key] = value
    }
}
