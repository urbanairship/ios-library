/* Copyright Airship and Contributors */

import Foundation
@_spi(AirshipInternal) import AirshipBasement

@MainActor
final class EmbeddedLastDisplayedTracker {
    static let shared = EmbeddedLastDisplayedTracker()

    private var lastDisplayed: [String: String] = [:]

    func record(embeddedID: String, instanceID: String) {
        AirshipLogger.trace("Updating last displayed for \(embeddedID): \(instanceID)")
        lastDisplayed[embeddedID] = instanceID
    }

    func lastDisplayedID(for embeddedID: String) -> String? {
        lastDisplayed[embeddedID]
    }
}
