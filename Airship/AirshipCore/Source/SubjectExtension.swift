/* Copyright Airship and Contributors */
import Combine
import Foundation

extension Subject {
    @MainActor
    func sendMainActor(_ value: Self.Output) {
        self.send(value)
    }
}
