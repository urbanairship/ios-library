/* Copyright Airship and Contributors */

public import Foundation
#if canImport(AirshipCore)
import AirshipCore
#endif

/// The privacy manager allow enabling/disabling features in the SDK.
/// The SDK will not make any network requests or collect data if all features are disabled, with
/// a few exceptions when going from enabled -> disabled. To have the SDK opt-out of all features on startup,
/// set the default enabled features in the Config to an empty option set, or in the
/// airshipconfig.plist file with `enabledFeatures = none`.
/// If any feature is enabled, the SDK will collect and send the following data:
/// - Channel ID
/// - Locale
/// - TimeZone
/// - Platform
/// - Opt in state (push and notifications)
/// - SDK version
/// - Accengage Device ID (Accengage module for migration)
@objc
public final class UAPrivacyManager: NSObject, Sendable {

    override init() {
        super.init()
    }
    
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
