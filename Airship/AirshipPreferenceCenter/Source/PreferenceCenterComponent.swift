/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Actual airship component for PreferenceCenter. Used to hide AirshipComponent methods.
final class PreferenceCenterComponent : AirshipComponent {
    final let preferenceCenter: PreferenceCenter

    init(preferenceCenter: PreferenceCenter) {
        self.preferenceCenter = preferenceCenter
    }

    @MainActor
    public func deepLink(_ deepLink: URL) -> Bool {
        return self.preferenceCenter.deepLink(deepLink)
    }
}

