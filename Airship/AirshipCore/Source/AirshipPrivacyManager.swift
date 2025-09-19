/* Copyright Airship and Contributors */

import Foundation

/// The privacy manager allow enabling/disabling features in the SDK.
/// The SDK will not make any network requests or collect data if all features are disabled, with
/// a few exceptions when going from enabled -> disabled. To have the SDK opt-out of all features on startup,
/// set the default enabled features in the Config to an empty option set, or in the
/// airshipconfig.plist file with `enabledFeatures = none`.
/// If any feature is enabled, the SDK will collect and send the following data:
/// - Channel ID
/// - Contact ID
/// - Locale
/// - TimeZone
/// - Platform
/// - Opt in state (push and notifications)
/// - SDK version
public protocol AirshipPrivacyManagerProtocol: AnyObject, Sendable {
    /// The current set of enabled features.
    var enabledFeatures: AirshipFeature { get set }

    /// Enables features.
    /// This will append any features to the `enabledFeatures` property.
    /// - Parameter features: The features to enable.
    func enableFeatures(_ features: AirshipFeature)

    /// Disables features.
    /// This will remove any features to the `enabledFeatures` property.
    /// - Parameter features: The features to disable.
    func disableFeatures(_ features: AirshipFeature)

    /// Checks if a given feature is enabled.
    ///
    /// - Parameter feature: The features to check.
    /// - Returns: True if the provided features are enabled, otherwise false.
    func isEnabled(_ feature: AirshipFeature) -> Bool

    /// Checks if any feature is enabled.
    /// - Returns: `true` if a feature is enabled, otherwise `false`.
    func isAnyFeatureEnabled() -> Bool
}


protocol InternalAirshipPrivacyManagerProtocol: AirshipPrivacyManagerProtocol {
    /// Checks if any feature is enabled.
    /// - Parameters:
    ///     - ignoringRemoteConfig: true to ignore any remotely disable features, false to include them.
    /// - Returns: `true` if a feature is enabled, otherwise `false`.
    /// * - Note: For internal use only. :nodoc:
    func isAnyFeatureEnabled(ignoringRemoteConfig: Bool) -> Bool
}

final class AirshipPrivacyManager: InternalAirshipPrivacyManagerProtocol {
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

    private let lastUpdated = AirshipAtomicValue<AirshipFeature>([])

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

    @MainActor
    init(
        dataStore: PreferenceDataStore,
        config: RuntimeConfig,
        defaultEnabledFeatures: AirshipFeature,
        notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter.shared
    ) {

        self.dataStore = dataStore
        self.config = config
        self.defaultEnabledFeatures = defaultEnabledFeatures
        self.notificationCenter = notificationCenter

        if config.airshipConfig.resetEnabledFeatures {
            self.dataStore.removeObject(forKey:  AirshipPrivacyManager.enabledFeaturesKey)
        } 

        self.lastUpdated.value = self.enabledFeatures

        self.migrateData()

        self.config.addRemoteConfigListener { [weak self] _, _ in
            self?.notifyUpdate()
        }
    }

    func enableFeatures(_ features: AirshipFeature) {
        self.enabledFeatures.insert(features)
    }

    func disableFeatures(_ features: AirshipFeature) {
        self.enabledFeatures.remove(features)
    }

    func isEnabled(_ feature: AirshipFeature) -> Bool {
        guard feature == [] else {
            return (enabledFeatures.rawValue & feature.rawValue) == feature.rawValue
        }
        return enabledFeatures == []
    }

    func isAnyFeatureEnabled() -> Bool {
        return isAnyFeatureEnabled(ignoringRemoteConfig: false)
    }

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
            guard enabledFeatures != lastUpdated.value else { return }
            self.lastUpdated.value = enabledFeatures
            self.notificationCenter.postOnMain(
                name: AirshipNotifications.PrivacyManagerUpdated.name
            )
        }
    }
}

/// Airship Features.
public struct AirshipFeature: OptionSet, Sendable, CustomStringConvertible {
    
    public let rawValue: UInt

    /// In-App automation
    public static let inAppAutomation = AirshipFeature(rawValue: 1 << 0)

    /// Message Center
    public static let messageCenter = AirshipFeature(rawValue: 1 << 1)

    /// Push
    public static let push = AirshipFeature(rawValue: 1 << 2)

    /// Analytics
    public static let analytics = AirshipFeature(rawValue: 1 << 4)

    /// Tags, attributes, and subscription lists
    public static let tagsAndAttributes = AirshipFeature(rawValue: 1 << 5)

    /// Contacts
    public static let contacts = AirshipFeature(rawValue: 1 << 6)

    /* Do not use: UAFeaturesLocation = (1 << 7) */

    /// Feature flags
    public static let featureFlags = AirshipFeature(rawValue: 1 << 8)

    /// All features
    public static let all: AirshipFeature = [
        inAppAutomation,
        messageCenter,
        push,
        analytics,
        tagsAndAttributes,
        contacts,
        featureFlags
    ]

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

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.names)
    }

    public init(from decoder: any Decoder) throws {
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
    final class PrivacyManagerUpdated {

        /// NSNotification name.
        public static let name = NSNotification.Name(
            "com.urbanairship.privacymanager.enabledfeatures_changed"
        )
    }
}
