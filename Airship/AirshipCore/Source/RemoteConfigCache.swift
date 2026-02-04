/* Copyright Airship and Contributors */

/// NOTE: For internal use only. :nodoc:
final class RemoteConfigCache: Sendable {
    private static let dataStoreKey: String = "com.urbanairship.config.remote_config_cache"
    private let dataStore: PreferenceDataStore
    private let _remoteConfig: AirshipAtomicValue<RemoteConfig>

    var remoteConfig: RemoteConfig {
        get {
            return _remoteConfig.value
        }
        set {
            _remoteConfig.value = newValue
            do {
                try self.dataStore.setCodable(
                    newValue,
                    forKey: RemoteConfigCache.dataStoreKey
                )
            } catch {
                AirshipLogger.error("Failed to store remote config cache \(error)")
            }
        }
    }

    init(dataStore: PreferenceDataStore) {
        self.dataStore = dataStore
        
        var fromStore: RemoteConfig? = nil
        do {
            fromStore = try dataStore.codable(
                forKey: RemoteConfigCache.dataStoreKey
            )
        } catch {
            AirshipLogger.error("Failed to read remote config cache \(error)")
        }
        
        self._remoteConfig = AirshipAtomicValue(fromStore ?? RemoteConfig())
    }
}
