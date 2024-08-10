/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

protocol ScheduleConditionsChangedNotifierProtocol {
    @MainActor
    func notify()

    @MainActor
    func wait() async
}


/// NOTE: For internal use only. :nodoc:
final class ScheduleConditionsChangedNotifier : @unchecked Sendable, ScheduleConditionsChangedNotifierProtocol {
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
