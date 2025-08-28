/* Copyright Airship and Contributors */



#if canImport(AirshipCore)
import AirshipCore
#endif

protocol ScheduleConditionsChangedNotifierProtocol: Sendable {
    @MainActor
    func notify()

    @MainActor
    func wait() async
}


/// NOTE: For internal use only. :nodoc:
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
