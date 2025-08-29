/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

protocol AutomationDelayProcessorProtocol: Sendable {
    // Waits for the delay
    @MainActor
    func process(delay: AutomationDelay?, triggerDate: Date) async

    // Waits for any delay - 30s and to be a display window if set
    func preprocess(delay: AutomationDelay?, triggerDate: Date) async throws

    // Checks if conditions are met
    @MainActor
    func areConditionsMet(delay: AutomationDelay?) -> Bool
}

final class AutomationDelayProcessor: AutomationDelayProcessorProtocol {
    private let analytics: any InternalAnalyticsProtocol
    private let appStateTracker: any AppStateTrackerProtocol
    private let taskSleeper: any AirshipTaskSleeper
    private let date: any AirshipDateProtocol
    private let screen: AirshipMainActorValue<String?> = AirshipMainActorValue(nil)
    private let executionWindowProcessor: any ExecutionWindowProcessorProtocol

    private static let preprocessSecondsDelayAllowance: TimeInterval = 30.0

    @MainActor
    init(
        analytics: any InternalAnalyticsProtocol,
        appStateTracker: (any AppStateTrackerProtocol)? = nil,
        taskSleeper: any AirshipTaskSleeper = .shared,
        date: any AirshipDateProtocol = AirshipDate.shared,
        executionWindowProcessor: (any ExecutionWindowProcessorProtocol)? = nil
    ) {
        self.analytics = analytics
        self.appStateTracker = appStateTracker ?? AppStateTracker.shared
        self.taskSleeper = taskSleeper
        self.date = date
        self.executionWindowProcessor = executionWindowProcessor ?? ExecutionWindowProcessor(
            taskSleeper: taskSleeper,
            date: date
        )
    }

    private func remainingSeconds(delay: AutomationDelay, triggerDate: Date) -> TimeInterval {
        guard let seconds = delay.seconds else { return 0 }
        let remaining = seconds - date.now.timeIntervalSince(triggerDate)
        return remaining > 0 ? remaining : 0
    }

    @MainActor
    func process(delay: AutomationDelay?, triggerDate: Date) async {
        guard let delay = delay else { return }

        /// Seconds
        let seconds = remainingSeconds(delay: delay, triggerDate: triggerDate)
        if seconds > 0 {
            try? await self.taskSleeper.sleep(timeInterval: seconds)
        }

        while !Task.isCancelled, !areConditionsMet(delay:delay) {
            /// App state
            if let appState = delay.appState {
                for await update in self.appStateTracker.stateUpdates {
                    guard !Task.isCancelled else { return }
                    if (appState == update.automationAppState) {
                        break
                    }
                }
            }

            guard !Task.isCancelled else { return }

            // Screen
            if let screens = delay.screens {
                for await update in self.analytics.screenUpdates {
                    guard !Task.isCancelled else { return }
                    if let update = update, screens.contains(update) {
                        break
                    }
                }
            }

            guard !Task.isCancelled else { return }

            // Region
            if let regionID = delay.regionID {
                guard !Task.isCancelled else { return }
                for await update in self.analytics.regionUpdates {
                    if update.contains(regionID) {
                        break
                    }
                }
            }
            
            guard !Task.isCancelled else { return }
            
            if let window = delay.executionWindow {
                try? await executionWindowProcessor.process(window: window)
            }
        }
    }

    func preprocess(delay: AutomationDelay?, triggerDate: Date) async throws {
        guard let delay = delay else { return }

        // Handle delay - preprocessSecondsDelayAllowance
        let seconds = remainingSeconds(delay: delay, triggerDate: triggerDate) - Self.preprocessSecondsDelayAllowance
        if seconds > 0 {
            try await self.taskSleeper.sleep(timeInterval: seconds)
        }

        try Task.checkCancellation()

        if let window = delay.executionWindow {
            try await executionWindowProcessor.process(window: window)
        }
    }

    @MainActor
    func areConditionsMet(delay: AutomationDelay?) -> Bool {
        guard let delay = delay else { return true }

        // State
        if let appState = delay.appState {
            guard appState == self.appStateTracker.state.automationAppState else {
                return false
            }
        }

        // Screen
        if let screens = delay.screens {
            guard 
                let currentScreen = analytics.currentScreen,
                screens.contains(currentScreen)
            else {
                return false
            }
        }

        // Region
        if let regionID = delay.regionID {
            guard self.analytics.currentRegions.contains(regionID) else {
                return false
            }
        }
        
        if let window = delay.executionWindow {
            guard executionWindowProcessor.isActive(window: window) else {
                return false
            }
        }

        return true
    }
}

fileprivate extension ApplicationState {
    @MainActor
    var automationAppState: AutomationAppState {
        if self == .active {
            return .foreground
        } else {
            return .background
        }
    }
}
