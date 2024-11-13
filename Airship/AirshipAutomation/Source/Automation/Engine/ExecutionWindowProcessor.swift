/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
import AirshipCore
#endif

import Foundation


protocol ExecutionWindowProcessorProtocol: Actor {
    func process(window: ExecutionWindow) async throws
    @MainActor
    func isActive(window: ExecutionWindow) -> Bool
}

actor ExecutionWindowProcessor: ExecutionWindowProcessorProtocol {
    private let taskSleeper: any AirshipTaskSleeper
    private let date: any AirshipDateProtocol
    private let onEvaluate: @Sendable (ExecutionWindow, Date) throws -> ExecutionWindowResult

    private var sleepTasks: [String: Task<Void, any Error>] = [:]

    init(
        taskSleeper: any AirshipTaskSleeper,
        date: any AirshipDateProtocol,
        notificationCenter: NotificationCenter = NotificationCenter.default,
        onEvaluate: @escaping @Sendable (ExecutionWindow, Date) throws -> ExecutionWindowResult = { window, date in
            try window.nextAvailability(date: date)
        }
    ) {
        self.taskSleeper = taskSleeper
        self.date = date
        self.onEvaluate = onEvaluate

        notificationCenter.addObserver(forName: .NSSystemTimeZoneDidChange, object: nil, queue: nil) { [weak self] _ in
            Task { [weak self] in
                await self?.timeZoneChanged()
            }
        }
    }

    private func timeZoneChanged() {
        self.sleepTasks.values.forEach { $0.cancel() }
    }

    private func sleep(delay: TimeInterval) async {
        let id = UUID().uuidString

        let sleepTask = Task {
            try await self.taskSleeper.sleep(timeInterval: delay)
        }

        sleepTasks[id] = sleepTask
        try? await sleepTask.value
        sleepTasks[id] = nil
    }


    private nonisolated func nextAvailability(window: ExecutionWindow) -> ExecutionWindowResult {
        do {
            return try onEvaluate(window, date.now)
        } catch {
            // We failed to process the window, use a long retry to prevent it from
            // busy waiting
            AirshipLogger.error("Failed to process execution window \(error)")
            return .retry(60 * 60 * 24)
        }
    }

    @MainActor
    func process(window: ExecutionWindow) async {
        while case .retry(let delay) = nextAvailability(window: window) {
            if Task.isCancelled { return }
            await sleep(delay: delay)
            if Task.isCancelled { return }
        }
    }

    @MainActor
    func isActive(window: ExecutionWindow) -> Bool {
        return nextAvailability(window: window) == .now
    }
}
