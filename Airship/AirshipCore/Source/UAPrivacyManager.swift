/* Copyright Airship and Contributors */

import Foundation

/// The privacy manager allow enabling/disabling features in the SDK.
/// The SDK will not make any network requests or collect data if all features our disabled, with
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
@objc(UAPrivacyManager)
public final class AirshipPrivacyManager: NSObject, Sendable {

    /**
    * NSNotification event when enabled feature list is updated.
     */
    @objc
    public static let changeEvent = Notification.Name(
        "com.urbanairship.privacymanager.enabledfeatures_changed"
    )

    private static let enabledFeaturesKey = "com.urbanairship.privacymanager.enabledfeatures"
    private let LegacyIAAEnableFlag = "UAInAppMessageManagerEnabled"
    private let LegacyChatEnableFlag = "AirshipChat.enabled"
    private let LegacyLocationEnableFlag = "UALocationUpdatesEnabled"
    private let LegacyAnalyticsEnableFlag = "UAAnalyticsEnabled"
    private let LegacyPushTokenRegistrationEnableFlag = "UAPushTokenRegistrationEnabled"
    private let LegacyDataCollectionEnableEnableFlag = "com.urbanairship.data_collection_enabled"

    private let dataStore: PreferenceDataStore

    private let notificationCenter: AirshipNotificationCenter

    private let currentEnabledFeatures: Atomic<AirshipFeature> = Atomic([])

    /// The current set of enabled features.
    public var enabledFeatures: AirshipFeature {
        get {
            return currentEnabledFeatures.value
        }
        set {
            let changed = currentEnabledFeatures.setValue(newValue) {
                self.dataStore.setObject(
                    NSNumber(value: newValue.rawValue),
                    forKey: AirshipPrivacyManager.enabledFeaturesKey
                )
            }

            if (changed) {
                self.notificationCenter.postOnMain(name: AirshipPrivacyManager.changeEvent)
            }
        }
    }

    /// :nodoc:
    @objc(enabledFeatures)
    public var _objc_enabledFeatures: _UAFeatures {
        get {
            return enabledFeatures.toObjc
        }
        set {
            enabledFeatures = newValue.toSwift
        }
    }

    /*
     * - Note: For internal use only. :nodoc:
     */
    @objc(privacyManagerWithDataStore:defaultEnabledFeatures:resetEnabledFeatures:)
    public static func _objc_factory(
        dataStore: PreferenceDataStore,
        defaultEnabledFeatures: _UAFeatures,
        resetEnabledFeatures: Bool) -> AirshipPrivacyManager {
            return AirshipPrivacyManager(dataStore: dataStore,
                                         defaultEnabledFeatures: defaultEnabledFeatures.toSwift,
                                         resetEnabledFeatures: resetEnabledFeatures)
    }

    /*
     * - Note: For internal use only. :nodoc:
     */
    public init(
        dataStore: PreferenceDataStore,
        defaultEnabledFeatures: AirshipFeature,
        resetEnabledFeatures: Bool,
        notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter.shared
    ) {

        self.dataStore = dataStore
        self.notificationCenter = notificationCenter

        if !resetEnabledFeatures,
           self.dataStore.keyExists(AirshipPrivacyManager.enabledFeaturesKey),
           let value = self.dataStore.unsignedInteger(forKey: AirshipPrivacyManager.enabledFeaturesKey) {
            self.currentEnabledFeatures.value = AirshipFeature(rawValue:(value & AirshipFeature.all.rawValue))
        } else {
            self.currentEnabledFeatures.value = defaultEnabledFeatures
        }

        super.init()
        self.migrateData()
    }

    /// Enables features.
    /// This will append any features to the `enabledFeatures` property.
    /// - Parameter features: The features to enable.
    public func enableFeatures(_ features: AirshipFeature) {
        self.enabledFeatures.insert(features)
    }

    /// :nodoc:
    @objc(enableFeatures:)
    public func _objc_enableFeatures(_ features: _UAFeatures) {
        enableFeatures(features.toSwift)
    }

    /// Disables features.
    /// This will remove any features to the `enabledFeatures` property.
    /// - Parameter features: The features to disable.
    public func disableFeatures(_ features: AirshipFeature) {
        self.enabledFeatures.remove(features)
    }

    /// :nodoc:
    @objc(disableFeatures:)
    public func _objc_disableFeatures(_ features: _UAFeatures) {
        disableFeatures(features.toSwift)
    }

    /**
    * Checks if a given feature is enabled.
    *
    * - Parameter feature: The features to check.
    * - Returns: True if the provided features are enabled, otherwise false.
    */
    public func isEnabled(_ feature: AirshipFeature) -> Bool {
        guard feature == [] else {
            return (enabledFeatures.rawValue & feature.rawValue) == feature.rawValue
        }
        return enabledFeatures == []
    }

    /// :nodoc:
    @objc(isEnabled:)
    public func _objc_isEnabled(_ features: _UAFeatures) -> Bool {
        return isEnabled(features.toSwift)
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
        var features = currentEnabledFeatures.value
        if dataStore.keyExists(LegacyDataCollectionEnableEnableFlag) {
            if dataStore.bool(forKey: LegacyDataCollectionEnableEnableFlag) {
                features = .all
            } else {
                features = []
            }
            dataStore.removeObject(forKey: LegacyDataCollectionEnableEnableFlag)
        }

        if dataStore.keyExists(LegacyPushTokenRegistrationEnableFlag) {
            if !(dataStore.bool(forKey: LegacyPushTokenRegistrationEnableFlag))
            {
                features.remove(.push)
            }
            dataStore.removeObject(
                forKey: LegacyPushTokenRegistrationEnableFlag
            )
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
            dataStore.removeObject(forKey: LegacyChatEnableFlag)
        }

        if dataStore.keyExists(LegacyLocationEnableFlag) {
            dataStore.removeObject(forKey: LegacyLocationEnableFlag)
        }

        currentEnabledFeatures.value = features
    }
}

/**
 * Airship features.
 */
public struct AirshipFeature: OptionSet, Sendable {
    
    public let rawValue: UInt

    // Enables In-App Automation.
    // In addition to the default data collection, In-App Automation will collect:
    // - App Version (App update triggers)
    public static let inAppAutomation = AirshipFeature(rawValue: _UAFeatures.inAppAutomation.rawValue)

    // Enables Message Center.
    // In addition to the default data collection, Message Center will collect:
    // - Message Center User
    // - Message Reads & Deletes
    public static let messageCenter = AirshipFeature(rawValue: _UAFeatures.messageCenter.rawValue)

    // Enables push.
    // In addition to the default data collection, push will collect:
    // - Push tokens
    public static let push = AirshipFeature(rawValue: _UAFeatures.push.rawValue)

    // Enables analytics.
    // In addition to the default data collection, analytics will collect:
    // -  Events
    // - Associated Identifiers
    // - Registered Notification Types
    // - Time in app
    // - App Version
    // - Device model
    // - Device manufacturer
    // - OS version
    // - Carrier
    // - Connection type
    // - Framework usage
    public static let analytics = AirshipFeature(rawValue: _UAFeatures.analytics.rawValue)

    // Enables tags and attributes.
    // In addition to the default data collection, tags and attributes will collect:
    // - Channel and Contact Tags
    // - Channel and Contact Attributes
    public static let tagsAndAttributes = AirshipFeature(rawValue: _UAFeatures.tagsAndAttributes.rawValue)

    // Enables contacts.
    // In addition to the default data collection, contacts will collect:
    // External ids (named user)
    public static let contacts = AirshipFeature(rawValue: _UAFeatures.contacts.rawValue)

    public static let all: AirshipFeature = [inAppAutomation, messageCenter, push, analytics, tagsAndAttributes, contacts]

    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }
}


extension AirshipFeature {
    var toObjc: _UAFeatures {
        return _UAFeatures(rawValue: self.rawValue)
    }
}

extension _UAFeatures {
    var toSwift: AirshipFeature {
        return AirshipFeature(rawValue: self.rawValue)
    }
}
