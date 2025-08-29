/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Actual airship component for FeatureFlags. Used to hide AirshipComponent methods.
final class FeatureFlagComponent : AirshipComponent {
    final let featureFlagManager: FeatureFlagManager

    init(featureFlagManager: FeatureFlagManager) {
        self.featureFlagManager = featureFlagManager
    }
}

