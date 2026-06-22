/* Copyright Airship and Contributors */

import Foundation

import AirshipCore

protocol ScheduleConditionsChangedNotifierProtocol: Sendable {
    @MainActor
    func notify()

    @MainActor
    func wait() async
}

@MainActor
final class ScheduleConditionsChangedNotifier: Sendable, ScheduleConditionsChangedNotifierProtocol {
    private var waiting: [CheckedContinuation<Void, Never>] = []

    @MainActor
    func notify() {
        waiting.forEach { continuation in
            continuation.resume()
        }
        waiting.removeAll()
    }

    @MainActor
    func wait() async {
        return await withCheckedContinuation { continuation in
            waiting.append(continuation)
        }
    }
}
