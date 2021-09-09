/* Copyright Airship and Contributors */

// NOTE: For internal use only. :nodoc:
class RemoteConfigCache  {
    private static let dataStoreKey = "com.urbanairship.config.remote_config_cache"
    private let dataStore: PreferenceDataStore
    
    private var _remoteConfig: RemoteConfig?
    
    var remoteConfig: RemoteConfig? {
        get {
            return _remoteConfig
        }
        set {
            _remoteConfig = newValue
            if (newValue != nil) {
                if let data = try? JSONEncoder().encode(newValue) {
                    self.dataStore.setValue(data, forKey: RemoteConfigCache.dataStoreKey)
                }
            }
        }
    }
    
    init(dataStore: PreferenceDataStore) {
        self.dataStore = dataStore
    
        if let data = self.dataStore.data(forKey: RemoteConfigCache.dataStoreKey) {
            self._remoteConfig = try? JSONDecoder().decode(RemoteConfig.self, from: data)
        }
    }
}
