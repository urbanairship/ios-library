

@_spi(AirshipInternal) @testable import AirshipCore
@_spi(AirshipInternal) import AirshipBasement
import Foundation

final class TestPrivacyManager: InternalAirshipPrivacyManager, @unchecked Sendable {
    func isAnyFeatureEnabled() -> Bool {
        return isAnyFeatureEnabled(ignoringRemoteConfig: false)
    }

    private static let enabledFeaturesKey = "com.urbanairship.privacymanager.enabledfeatures"

    private let dataStore: PreferenceDataStore
    private let config: RuntimeConfig
    let notificationCenter: AirshipNotificationCenter

    private let defaultEnabledFeatures: AirshipFeature

    private let lock: AirshipLock = AirshipLock()
    private var lastUpdated: AirshipFeature = []

    private var _enabledFeatures: AirshipFeature = []

    private var localEnabledFeatures: AirshipFeature {
        get {
            guard let fromStore = self.dataStore.unsignedInteger(forKey: TestPrivacyManager.enabledFeaturesKey) else {
                return self.defaultEnabledFeatures
            }

            return AirshipFeature(
                rawValue:(fromStore & AirshipFeature.all.rawValue)
            )
        }
        set {
            self.dataStore.setValue(
                newValue.rawValue,
                forKey: TestPrivacyManager.enabledFeaturesKey
            )
        }
    }

    init(
        dataStore: PreferenceDataStore,
        config: RuntimeConfig,
        defaultEnabledFeatures: AirshipFeature = [],
        notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter()
    ) {
        self.dataStore = PreferenceDataStore(appKey: UUID().uuidString)
        self.config = RuntimeConfig.testConfig()
        self.defaultEnabledFeatures = defaultEnabledFeatures
        self.notificationCenter = notificationCenter

        self.notifyUpdate()
    }

    /// The current set of enabled features.
    public var enabledFeatures: AirshipFeature {
        get {
            self.localEnabledFeatures.subtracting(self.config.remoteConfig.disabledFeatures ?? [])
        }
        set {
            lock.sync {
                self.localEnabledFeatures = newValue
                notifyUpdateLocked()
            }
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

    func isAnyFeatureEnabled(ignoringRemoteConfig: Bool) -> Bool {
        if ignoringRemoteConfig {
            return localEnabledFeatures != []
        } else {
            return enabledFeatures != []
        }
    }

    private func notifyUpdate() {
        lock.sync {
            notifyUpdateLocked()
        }
    }

    /// Caller must hold `lock`.
    private func notifyUpdateLocked() {
        let enabledFeatures = self.enabledFeatures
        guard enabledFeatures != lastUpdated else { return }
        self.lastUpdated = enabledFeatures
        self.notificationCenter.postOnMain(
            name: AirshipNotifications.PrivacyManagerUpdated.name
        )
    }
}
