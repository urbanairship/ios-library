/* Copyright Airship and Contributors */
import Combine


extension Subject {
    @MainActor
    func sendMainActor(_ value: Self.Output) {
        self.send(value)
    }
}
