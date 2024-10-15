/* Copyright Airship and Contributors */

import Foundation
public import AirshipCore

@objc
public class OUAPrivacyManager: NSObject {
    
    /// The current set of enabled features.
    @objc(enabledFeatures)
    public var enabledFeatures: _UAFeatures {
        get {
            return Airship.privacyManager.enabledFeatures.toObjc
        }
        set {
            Airship.privacyManager.enabledFeatures = newValue.toSwift
        }
    }
    
    /// Enables features.
    /// This will append any features to the `enabledFeatures` property.
    /// - Parameter features: The features to enable.
    @objc(enableFeatures:)
    public func enableFeatures(_ features: _UAFeatures) {
        Airship.privacyManager.enableFeatures(features.toSwift)
    }
    
    /// Disables features.
    /// This will remove any features to the `enabledFeatures` property.
    /// - Parameter features: The features to disable.
    @objc(disableFeatures:)
    public func disableFeatures(_ features: _UAFeatures) {
        Airship.privacyManager.disableFeatures(features.toSwift)
    }
    
    /**
     * Checks if a given feature is enabled.
     *
     * - Parameter feature: The features to check.
     * - Returns: True if the provided features are enabled, otherwise false.
     */
    @objc(isEnabled:)
    public func isEnabled(_ features: _UAFeatures) -> Bool {
        return Airship.privacyManager.isEnabled(features.toSwift)
    }
    
    /// Checks if any feature is enabled.
    /// - Returns: `true` if a feature is enabled, otherwise `false`.
    @objc
    public func isAnyFeatureEnabled() -> Bool {
        return Airship.privacyManager.isAnyFeatureEnabled()
    }
}
