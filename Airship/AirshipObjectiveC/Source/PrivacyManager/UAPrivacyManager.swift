/* Copyright Airship and Contributors */

public import Foundation
#if canImport(AirshipCore)
import AirshipCore
#endif

@objc
public final class UAPrivacyManager: NSObject, Sendable {

    /// The current set of enabled features.
    @objc(enabledFeatures)
    public var enabledFeatures: UAFeature {
        get {
            return Airship.privacyManager.enabledFeatures.asUAFeature
        }
        set {
            Airship.privacyManager.enabledFeatures = newValue.asAirshipFeature
        }
    }
    
    /// Enables features.
    /// This will append any features to the `enabledFeatures` property.
    /// - Parameter features: The features to enable.
    @objc(enableFeatures:)
    public func enableFeatures(_ features: UAFeature) {
        Airship.privacyManager.enableFeatures(features.asAirshipFeature)
    }
    
    /// Disables features.
    /// This will remove any features to the `enabledFeatures` property.
    /// - Parameter features: The features to disable.
    @objc(disableFeatures:)
    public func disableFeatures(_ features: UAFeature) {
        Airship.privacyManager.disableFeatures(features.asAirshipFeature)
    }
    
    /**
     * Checks if a given feature is enabled.
     *
     * - Parameter features: The features to check.
     * - Returns: True if the provided features are enabled, otherwise false.
     */
    @objc(isEnabled:)
    public func isEnabled(_ features: UAFeature) -> Bool {
        return Airship.privacyManager.isEnabled(features.asAirshipFeature)
    }
    
    /// Checks if any feature is enabled.
    /// - Returns: `true` if a feature is enabled, otherwise `false`.
    @objc
    public func isAnyFeatureEnabled() -> Bool {
        return Airship.privacyManager.isAnyFeatureEnabled()
    }
}