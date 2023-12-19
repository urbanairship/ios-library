/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Display coordinator that only allows a single message at a time to be displayed with an optional interval between
/// displays.
@MainActor
final class DefaultDisplayCoordinator: DisplayCoordinator {

    private enum LockState {
        case unlocked
        case locked
        case unlocking
    }

    private var lockState: LockState = .unlocked
    private let appStateTracker: AppStateTrackerProtocol
    private let taskSleeper: AirshipTaskSleeper
    private var unlockTask: Task<Void, Never>?

    public var displayInterval: TimeInterval {
        didSet {
            if self.lockState == .unlocking {
                self.unlockTask?.cancel()
                startUnlockTask()
            }
        }
    }

    init(
        displayInterval: TimeInterval,
        appStateTracker: AppStateTrackerProtocol? = nil,
        taskSleeper: AirshipTaskSleeper = .shared
    ) {
        self.displayInterval = displayInterval
        self.appStateTracker = appStateTracker ?? AppStateTracker.shared
        self.taskSleeper = taskSleeper
    }

    var isReady: Bool {
        return lockState == .unlocked && self.appStateTracker.state == .active
    }

    func didBeginDisplayingMessage(_ message: InAppMessage) {
        self.lockState = .locked
    }

    func didFinishDisplayingMessage(_ message: InAppMessage) {
        self.startUnlockTask()
    }

    private func startUnlockTask() {
        guard self.lockState == .locked else {
            return
        }
        
        self.lockState = .unlocking
        self.unlockTask = Task { @MainActor in
            try? await self.taskSleeper.sleep(timeInterval: self.displayInterval)
            if (!Task.isCancelled) {
                self.lockState = .unlocked
            }
        }
    }

    func waitForReady() async {
        while isReady == false {
            await self.unlockTask?.value
            await self.appStateTracker.waitForActive()
        }
    }
}
