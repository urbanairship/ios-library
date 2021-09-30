/* Copyright Airship and Contributors */

import Foundation;

/**
 * The privacy manager allow enabling/disabling features in the SDK.
 * The SDK will not make any network requests or collect data if all features our disabled, with
 * a few exceptions when going from enabled -> disabled. To have the SDK opt-out of all features on startup,
 * set the default enabled features in the Config to an empty option set, or in the
 * airshipconfig.plist file with `enabledFeatures = none`.
 * If any feature is enabled, the SDK will collect and send the following data:
 * - Channel ID
 * - Locale
 * - TimeZone
 * - Platform
 * - Opt in state (push and notifications)
 * - SDK version
 * - Accengage Device ID (Accengage module for migration)
 */
@objc(UAPrivacyManager)
public class PrivacyManager : NSObject {

    /**
    * NSNotification event when enabled feature list is updated.
     */
    @objc
    public static let changeEvent = Notification.Name("com.urbanairship.privacymanager.enabledfeatures_changed")

    private let UAPrivacyManagerEnabledFeaturesKey = "com.urbanairship.privacymanager.enabledfeatures"
    private let LegacyIAAEnableFlag = "UAInAppMessageManagerEnabled"
    private let LegacyChatEnableFlag = "AirshipChat.enabled"
    private let LegacyLocationEnableFlag = "UALocationUpdatesEnabled"
    private let LegacyAnalyticsEnableFlag = "UAAnalyticsEnabled"
    private let LegacyPushTokenRegistrationEnableFlag = "UAPushTokenRegistrationEnabled"
    private let LegacyDataCollectionEnableEnableFlag = "com.urbanairship.data_collection_enabled"

    private let dataStore: PreferenceDataStore
    private let notificationCenter: NotificationCenter

    private var _enabledFeatures: Features

    /// The current set of enabled features.
    @objc
    public var enabledFeatures: Features {
        get {
            _enabledFeatures
        } set {
            if (_enabledFeatures != newValue) {
                _enabledFeatures = newValue
                dataStore.setObject(NSNumber(value: enabledFeatures.rawValue), forKey: UAPrivacyManagerEnabledFeaturesKey)
                UADispatcher.main.dispatchAsyncIfNecessary({ [self] in
                    notificationCenter.post(name: PrivacyManager.changeEvent, object: nil)
                })
            }
        }
    }

    /*
     * - Note: For internal use only. :nodoc:
     */
    @objc
    public convenience init(dataStore: PreferenceDataStore, defaultEnabledFeatures: Features) {
        self.init(
            dataStore: dataStore,
            defaultEnabledFeatures: defaultEnabledFeatures,
            notificationCenter: NotificationCenter.default)
    }

    /*
     * - Note: For internal use only. :nodoc:
     */
    @objc
    public init(dataStore: PreferenceDataStore, defaultEnabledFeatures: Features, notificationCenter: NotificationCenter) {

        self.dataStore = dataStore
        self.notificationCenter = notificationCenter

        if self.dataStore.keyExists(UAPrivacyManagerEnabledFeaturesKey) {
            self._enabledFeatures = Features(rawValue: UInt(self.dataStore.integer(forKey: UAPrivacyManagerEnabledFeaturesKey)))
        } else {
            self._enabledFeatures = defaultEnabledFeatures
        }

        super.init()
        self.migrateData()
    }

    /// Enables features.
    /// This will append any features to the `enabledFeatures` property.
    /// - Parameter features: The features to enable.
    @objc
    public func enableFeatures(_ features: Features) {
        enabledFeatures.insert(features)
    }

    /// Disables features.
    /// This will remove any features to the `enabledFeatures` property.
    /// - Parameter features: The features to disable.
    @objc
    public func disableFeatures(_ features: Features) {
        enabledFeatures.remove(features)
    }

   /**
    * Checks if a given feature is enabled.
    *
    * - Parameter feature: The features to check.
    * - Returns: True if the provided features are enabled, otherwise false.
    */
    @objc
    public func isEnabled(_ feature: Features) -> Bool {
        if feature == .none {
            return enabledFeatures == .none
        } else {
            return (enabledFeatures.rawValue & feature.rawValue) == feature.rawValue
        }
    }

   /**
    * Checks if any feature is enabled.
    *
    * - Returns: True if any feature is enabled, otherwise false.
    */
    @objc
    public func isAnyFeatureEnabled() -> Bool {
        return enabledFeatures != []
    }

    func migrateData() {
        var features = _enabledFeatures
        if dataStore.keyExists(LegacyDataCollectionEnableEnableFlag) {
            if dataStore.bool(forKey: LegacyDataCollectionEnableEnableFlag) {
                features = .all
            } else {
                features = []
            }
            dataStore.removeObject(forKey: LegacyDataCollectionEnableEnableFlag)
        }

        if dataStore.keyExists(LegacyPushTokenRegistrationEnableFlag) {
            if !(dataStore.bool(forKey: LegacyPushTokenRegistrationEnableFlag)) {
                features.remove(.push)
            }
            dataStore.removeObject(forKey: LegacyPushTokenRegistrationEnableFlag)
        }

        if dataStore.keyExists(LegacyAnalyticsEnableFlag) {
            if !(dataStore.bool(forKey: LegacyAnalyticsEnableFlag)) {
                features.remove(.analytics)
            }
            dataStore.removeObject(forKey: LegacyAnalyticsEnableFlag)
        }

        if dataStore.keyExists(LegacyIAAEnableFlag) {
            if !(dataStore.bool(forKey: LegacyIAAEnableFlag)) {
                features.remove(.inAppAutomation)
            }
            dataStore.removeObject(forKey: LegacyIAAEnableFlag)
        }

        if dataStore.keyExists(LegacyChatEnableFlag) {
            if !(dataStore.bool(forKey: LegacyChatEnableFlag)) {
                features.remove(.chat)
            }
            dataStore.removeObject(forKey: LegacyChatEnableFlag)
        }

        if dataStore.keyExists(LegacyLocationEnableFlag) {
            if !(dataStore.bool(forKey: LegacyLocationEnableFlag)) {
                disableFeatures(.location)
            }
            dataStore.removeObject(forKey: LegacyLocationEnableFlag)
        }

        _enabledFeatures = features
    }
}
