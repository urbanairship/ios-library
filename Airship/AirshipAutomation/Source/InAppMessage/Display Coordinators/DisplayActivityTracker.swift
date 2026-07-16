/* Copyright Airship and Contributors */

import Foundation

import AirshipCore
@_spi(AirshipInternal) import AirshipBasement

/// Tracks messages that are currently displaying so display coordinators can
/// coordinate with each other.
@MainActor
final class DisplayActivityTracker {

    private let activeCount: AirshipMainActorValue<Int> = AirshipMainActorValue(0)

    var isDisplaying: Bool {
        return activeCount.value > 0
    }

    var activeCountUpdates: AsyncStream<Int> {
        return activeCount.updates
    }

    func messageWillDisplay() {
        activeCount.set(activeCount.value + 1)
    }

    func messageFinishedDisplaying() {
        activeCount.set(max(0, activeCount.value - 1))
    }
}
