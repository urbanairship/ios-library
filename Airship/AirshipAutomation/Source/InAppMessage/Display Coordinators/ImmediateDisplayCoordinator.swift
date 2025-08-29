/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif


/// A display coordinator that only requires the app to be active
@MainActor
final class ImmediateDisplayCoordinator: DisplayCoordinator {

    private let appStateTracker: any AppStateTrackerProtocol

    init(
        appStateTracker: (any AppStateTrackerProtocol)? = nil
    ) {
        self.appStateTracker = appStateTracker ?? AppStateTracker.shared
    }

    var isReady: Bool {
        return appStateTracker.state == .active
    }

    func messageWillDisplay(_ message: InAppMessage) {

    }

    func messageFinishedDisplaying(_ message: InAppMessage) {

    }

    func waitForReady() async {
        for await update in appStateTracker.stateUpdates {
            if Task.isCancelled {
                break
            }
            if update == .active {
                break
            }
        }
    }
}
