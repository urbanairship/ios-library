/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif


protocol AutomationDelayProcessorProtocol: Sendable {
    @MainActor
    func process(delay: AutomationDelay?, triggerDate: Date) async

    @MainActor
    func areConditionsMet(delay: AutomationDelay?) -> Bool
}

final class AutomationDelayProcessor: AutomationDelayProcessorProtocol {
    private let analytics: InternalAnalyticsProtocol
    private let appStateTracker: AppStateTrackerProtocol
    private let taskSleeper: AirshipTaskSleeper
    private let date: AirshipDateProtocol
    private let screen: AirshipMainActorValue<String?> = AirshipMainActorValue(nil)

    @MainActor
    init(
        analytics: InternalAnalyticsProtocol,
        appStateTracker: AppStateTrackerProtocol? = nil,
        taskSleeper: AirshipTaskSleeper = .shared,
        date: AirshipDateProtocol = AirshipDate.shared
    ) {
        self.analytics = analytics
        self.appStateTracker = appStateTracker ?? AppStateTracker.shared
        self.taskSleeper = taskSleeper
        self.date = date
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
