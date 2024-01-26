
import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif


protocol AutomationConditionsMonitorProtocol: Sendable {
    @MainActor
    func wait(delay: AutomationDelay?, startDate: Date) async
    @MainActor
    func isReady(_ delay: AutomationDelay?) -> Bool
}

final class AutomationConditionsMonitor: AutomationConditionsMonitorProtocol {
    let sleeper: AirshipTaskSleeper
    let date: AirshipDateProtocol

    init(
        sleeper: AirshipTaskSleeper = .shared,
        date: AirshipDateProtocol = AirshipDate.shared
    ) {
        self.sleeper = sleeper
        self.date = date
    }

    @MainActor
    func wait(delay: AutomationDelay?, startDate: Date) async {
        guard let delay = delay else { return }

        if let seconds = delay.seconds {
            let remaining = seconds - date.now.timeIntervalSince(startDate)
            if (remaining > 0) {
                try? await sleeper.sleep(timeInterval: remaining)
            }
        }

        // TODO wait for other criteria to be true if we can
    }

    @MainActor
    func isReady(_ delay: AutomationDelay?) -> Bool {
        // TODO  evalutes criteria
        return false
    }
}
