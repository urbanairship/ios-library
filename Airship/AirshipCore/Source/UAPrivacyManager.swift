/* Copyright Airship and Contributors */

import Foundation;

/**
 * The privacy manager allow enabling/disabling features in the SDK.
 * The SDK will not make any network requests or collect data if all features our disabled, with
 * a few exceptions when going from enabled -> disabled. To have the SDK opt-out of all features on startup,
 * set the default enabled features in the AirshipConfig to UAFeaturesNone, or in the
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
@objc
public class UAPrivacyManager : NSObject {


    /**
    * NSNotification event when enabled feature list is updated.
     */
    @objc
    public static let changeEvent = NSNotification.Name("com.urbanairship.privacymanager.enabledfeatures_changed")

    private let UAPrivacyManagerEnabledFeaturesKey = "com.urbanairship.privacymanager.enabledfeatures"
    private let LegacyIAAEnableFlag = "UAInAppMessageManagerEnabled"
    private let LegacyChatEnableFlag = "AirshipChat.enabled"
    private let LegacyLocationEnableFlag = "UALocationUpdatesEnabled"
    private let LegacyAnalyticsEnableFlag = "UAAnalyticsEnabled"
    private let LegacyPushTokenRegistrationEnableFlag = "UAPushTokenRegistrationEnabled"
    private let LegacyDataCollectionEnableEnableFlag = "com.urbanairship.data_collection_enabled"

    private let dataStore: UAPreferenceDataStore
    private let notificationCenter: NotificationCenter

    private var _enabledFeatures: UAFeatures

    /**
    * Gets the current enabled features.
    *
    * @return The enabled features.
    */
    @objc
    public var enabledFeatures: UAFeatures {
        get {
            _enabledFeatures
        } set {
            if (_enabledFeatures != newValue) {
                _enabledFeatures = newValue
                dataStore.setObject(NSNumber(value: enabledFeatures.rawValue), forKey: UAPrivacyManagerEnabledFeaturesKey)
                UADispatcher.main.dispatchAsyncIfNecessary({ [self] in
                    notificationCenter.post(name: UAPrivacyManager.changeEvent, object: nil)
                })
            }
        }
    }

    /*
     * @note For internal use only. :nodoc:
     */
    @objc
    public convenience init(dataStore: UAPreferenceDataStore, defaultEnabledFeatures: UAFeatures) {
        self.init(
            dataStore: dataStore,
            defaultEnabledFeatures: defaultEnabledFeatures,
            notificationCenter: NotificationCenter.default)
    }

    /*
     * @note For internal use only. :nodoc:
     */
    @objc
    public init(dataStore: UAPreferenceDataStore, defaultEnabledFeatures: UAFeatures, notificationCenter: NotificationCenter) {

        self.dataStore = dataStore
        self.notificationCenter = notificationCenter

        if self.dataStore.keyExists(UAPrivacyManagerEnabledFeaturesKey) {
            self._enabledFeatures = UAFeatures(rawValue: UInt(self.dataStore.integer(forKey: UAPrivacyManagerEnabledFeaturesKey)))
        } else {
            self._enabledFeatures = defaultEnabledFeatures
        }

        super.init()
        self.migrateData()
    }

    /**
    * Enables features.
    *
    * @param features The features to enable.
    */
    @objc
    public func enableFeatures(_ features: UAFeatures) {
        enabledFeatures.insert(features)
    }

    /**
    * Disables features.
    *
    * @param features The features to disable.
    */
    @objc
    public func disableFeatures(_ features: UAFeatures) {
        enabledFeatures.remove(features)
    }

    /**
    * Checks if a given feature is enabled.
    *
    * @param feature The features to check.
    * @return True if the provided features are enabled, otherwise false.
    */
    @objc
    public func isEnabled(_ feature: UAFeatures) -> Bool {
        if feature == .none {
            return enabledFeatures == .none
        } else {
            return (enabledFeatures.rawValue & feature.rawValue) == feature.rawValue
        }
    }

    /**
    * Checks if any feature is enabled.
    *
    * @return True if any feature is enabled, otherwise false.
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
