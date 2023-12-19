/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif


/// A display coordinator that only requires the app to be active
@MainActor
final class ImmediateDisplayCoordinator: DisplayCoordinator {

    private let appStateTracker: AppStateTrackerProtocol

    init(
        appStateTracker: AppStateTrackerProtocol? = nil
    ) {
        self.appStateTracker = appStateTracker ?? AppStateTracker.shared
    }

    var isReady: Bool {
        return self.appStateTracker.state == .active
    }

    func didBeginDisplayingMessage(_ message: InAppMessage) {
    }

    func didFinishDisplayingMessage(_ message: InAppMessage) {
    }

    func waitForReady() async {
        while isReady == false {
            await self.appStateTracker.waitForActive()
        }
    }
}
