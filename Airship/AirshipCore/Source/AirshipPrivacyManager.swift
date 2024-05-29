/* Copyright Airship and Contributors */

import Foundation

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
@objc(UAPrivacyManager)
public final class AirshipPrivacyManager: NSObject, @unchecked Sendable {

    private static let enabledFeaturesKey = "com.urbanairship.privacymanager.enabledfeatures"

    private let legacyIAAEnableFlag = "UAInAppMessageManagerEnabled"
    private let legacyChatEnableFlag = "AirshipChat.enabled"
    private let legacyLocationEnableFlag = "UALocationUpdatesEnabled"
    private let legacyAnalyticsEnableFlag = "UAAnalyticsEnabled"
    private let legacyPushTokenRegistrationEnableFlag = "UAPushTokenRegistrationEnabled"
    private let legacyDataCollectionEnableEnableFlag = "com.urbanairship.data_collection_enabled"

    private let dataStore: PreferenceDataStore
    private let config: RuntimeConfig
    private let defaultEnabledFeatures: AirshipFeature
    private let notificationCenter: AirshipNotificationCenter

    private let lock: AirshipLock = AirshipLock()

    private var lastUpdated: AirshipFeature = []

    private var localEnabledFeatures: AirshipFeature {
        get {
            guard let fromStore = self.dataStore.unsignedInteger(forKey: AirshipPrivacyManager.enabledFeaturesKey) else {
                return self.defaultEnabledFeatures
            }
            
            return AirshipFeature(
                rawValue:(fromStore & AirshipFeature.all.rawValue)
            )
        }
        set {
            self.dataStore.setValue(
                newValue.rawValue,
                forKey: AirshipPrivacyManager.enabledFeaturesKey
            )
        }
    }

    /// The current set of enabled features.
    public var enabledFeatures: AirshipFeature {
        get {
            self.localEnabledFeatures.subtracting(self.config.remoteConfig.disabledFeatures ?? [])
        }
        set {
            lock.sync {
                self.localEnabledFeatures = newValue
                notifyUpdate()
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
    @MainActor
    public init(
        dataStore: PreferenceDataStore,
        config: RuntimeConfig,
        defaultEnabledFeatures: AirshipFeature,
        notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter.shared
    ) {

        self.dataStore = dataStore
        self.config = config
        self.defaultEnabledFeatures = defaultEnabledFeatures
        self.notificationCenter = notificationCenter

        super.init()

        if config.resetEnabledFeatures {
            self.dataStore.removeObject(forKey:  AirshipPrivacyManager.enabledFeaturesKey)
        } 

        self.lastUpdated = self.enabledFeatures

        self.migrateData()

        self.config.addRemoteConfigListener { [weak self] _, _ in
            self?.notifyUpdate()
        }
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

    /// Checks if any feature is enabled.
    /// - Returns: `true` if a feature is enabled, otherwise `false`.
    @objc
    public func isAnyFeatureEnabled() -> Bool {
        return isAnyFeatureEnabled(ignoringRemoteConfig: false)
    }

    /// Checks if any feature is enabled.
    /// - Parameters:
    ///     - ignoringRemoteConfig: true to ignore any remotely disable features, false to include them.
    /// - Returns: `true` if a feature is enabled, otherwise `false`.
    func isAnyFeatureEnabled(ignoringRemoteConfig: Bool) -> Bool {
        if ignoringRemoteConfig {
            return localEnabledFeatures != []
        } else {
            return enabledFeatures != []
        }
    }

    func migrateData() {
        if dataStore.keyExists(legacyDataCollectionEnableEnableFlag) {
            if dataStore.bool(forKey: legacyDataCollectionEnableEnableFlag) {
                self.enabledFeatures = .all
            } else {
                self.enabledFeatures = []
            }
            dataStore.removeObject(forKey: legacyDataCollectionEnableEnableFlag)
        }

        if dataStore.keyExists(legacyPushTokenRegistrationEnableFlag) {
            if !(dataStore.bool(forKey: legacyPushTokenRegistrationEnableFlag)) {
                self.disableFeatures(.push)
            }
            dataStore.removeObject(
                forKey: legacyPushTokenRegistrationEnableFlag
            )
        }

        if dataStore.keyExists(legacyAnalyticsEnableFlag) {
            if !(dataStore.bool(forKey: legacyAnalyticsEnableFlag)) {
                self.disableFeatures(.analytics)
            }
            dataStore.removeObject(forKey: legacyAnalyticsEnableFlag)
        }

        if dataStore.keyExists(legacyIAAEnableFlag) {
            if !(dataStore.bool(forKey: legacyIAAEnableFlag)) {
                self.disableFeatures(.inAppAutomation)
            }
            dataStore.removeObject(forKey: legacyIAAEnableFlag)
        }

        if dataStore.keyExists(legacyChatEnableFlag) {
            dataStore.removeObject(forKey: legacyChatEnableFlag)
        }

        if dataStore.keyExists(legacyLocationEnableFlag) {
            dataStore.removeObject(forKey: legacyLocationEnableFlag)
        }
    }

    private func notifyUpdate() {
        lock.sync {
            let enabledFeatures = self.enabledFeatures
            guard enabledFeatures != lastUpdated else { return }
            self.lastUpdated = enabledFeatures
            self.notificationCenter.postOnMain(
                name: AirshipNotifications.PrivacyManagerUpdated.name
            )
        }
    }
}

/**
 * Airship features.
 */
public struct AirshipFeature: OptionSet, Sendable, CustomStringConvertible {
    
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
    
    // Enables feature flags.
    public static let featureFlags = AirshipFeature(rawValue: _UAFeatures.featureFlags.rawValue)

    public static let all: AirshipFeature = [inAppAutomation, messageCenter, push, analytics, tagsAndAttributes, contacts, featureFlags]

    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    public var description: String {
        var descriptions = [String]()
        if self.contains(.inAppAutomation) {
            descriptions.append("In-App Automation")
        }
        if self.contains(.messageCenter) {
            descriptions.append("Message Center")
        }
        if self.contains(.push) {
            descriptions.append("Push")
        }
        if self.contains(.analytics) {
            descriptions.append("Analytics")
        }
        if self.contains(.tagsAndAttributes) {
            descriptions.append("Tags and Attributes")
        }
        if self.contains(.contacts) {
            descriptions.append("Contacts")
        }
        if self.contains(.featureFlags) {
            descriptions.append("Feature flags")
        }

        // add prefix indicating that these are enabled features
        return "Enabled features: " + descriptions.joined(separator: ", ")
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


extension AirshipFeature: Codable {
    static let nameMap: [String: AirshipFeature] = [
        "push": .push,
        "contacts": .contacts,
        "message_center": .messageCenter,
        "analytics": .analytics,
        "tags_and_attributes": .tagsAndAttributes,
        "in_app_automation": .inAppAutomation,
        "feature_flags": .featureFlags,
        "all": .all,
        "none": []
    ]

    var names: [String] {
        var names: [String] = []
        if (self == .all) {
            return AirshipFeature.nameMap.keys.filter { key in
                key != "none" && key != "all"
            }
        }

        if (self == []) {
            return []
        }

        AirshipFeature.nameMap.forEach { key, value in
            if (value != [] && value != .all) {
                if (self.contains(value)) {
                    names.append(key)
                }
            }
        }

        return names
    }

    static func parse(_ names: [Any]) throws -> AirshipFeature {
        guard let names = names as? [String] else {
            throw AirshipErrors.error("Invalid feature \(names)")
        }

        var features: AirshipFeature = []

        try names.forEach { name in
            guard
                let feature = AirshipFeature.nameMap[name.lowercased()]
            else {
                throw AirshipErrors.error("Invalid feature \(name)")
            }
            features.update(with: feature)
        }

        return features
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.names)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let names: [String] = try? container.decode([String].self) {
            self = try AirshipFeature.parse(names)
        } else {
            throw AirshipErrors.error("Failed to parse features")
        }
    }
}


public extension AirshipNotifications {

    /// NSNotification info when enabled feature changed on PrivacyManager.
    @objc(UAirshipNotificationPrivacyManagerUpdated)
    final class PrivacyManagerUpdated: NSObject {

        /// NSNotification name.
        @objc
        public static let name = NSNotification.Name(
            "com.urbanairship.privacymanager.enabledfeatures_changed"
        )
    }
}
