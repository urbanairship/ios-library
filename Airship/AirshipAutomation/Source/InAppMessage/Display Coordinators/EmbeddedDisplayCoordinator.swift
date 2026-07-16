/* Copyright Airship and Contributors */

import Foundation

import AirshipCore
@_spi(AirshipInternal) import AirshipBasement

/// A display coordinator for embedded messages that only requires the app to be active.
/// Embedded displays do not count as a displaying message for other coordinators.
@MainActor
final class EmbeddedDisplayCoordinator: DisplayCoordinator {

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
