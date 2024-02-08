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

    private var lockState: AirshipMainActorValue<LockState> = AirshipMainActorValue(.unlocked)
    private let appStateTracker: AppStateTrackerProtocol
    private let taskSleeper: AirshipTaskSleeper
    private var unlockTask: Task<Void, Never>?

    public var displayInterval: TimeInterval {
        didSet {
            if self.lockState.value == .unlocking {
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
        return lockState.value == .unlocked && self.appStateTracker.state == .active
    }

    @MainActor
    func messageWillDisplay(_ message: InAppMessage) {
        self.lockState.set(.locked)
    }

    @MainActor
    func messageFinishedDisplaying(_ message: InAppMessage) {
        self.startUnlockTask()
    }


    @MainActor
    private func startUnlockTask() {
        guard 
            self.lockState.value != .unlocked
        else {
            return
        }
        
        self.lockState.set(.unlocking)
        self.unlockTask = Task { @MainActor in
            try? await self.taskSleeper.sleep(timeInterval: self.displayInterval)
            if (!Task.isCancelled) {
                self.lockState.set(.unlocked)
            }
        }
    }

    func waitForReady() async {
        while !isReady {
            if Task.isCancelled {
                return
            }

            for await state in self.lockState.updates {
                if (state == .unlocked) {
                    break
                }
            }

            for await state in self.appStateTracker.stateUpdates {
                if (state == .active) {
                    break
                }
            }
        }
    }
}
