/* Copyright Airship and Contributors */

/**
 * Preference data store.
 * - Note: For internal use only. :nodoc:
 */
@objc(UAPreferenceDataStore)
public class PreferenceDataStore : NSObject {
    private let defaults: UserDefaults
    private let appKey: String
    static let deviceIDKey = "deviceID"

    lazy var isAppRestore: Bool = {
        let deviceID = UAKeychainUtils.getDeviceID()
        let previousDeviceID = self.string(forKey: PreferenceDataStore.deviceIDKey)
        if (deviceID == previousDeviceID) {
            return false
        }

        var restored = previousDeviceID != nil
        if (restored)  {
            AirshipLogger.info("App restored")
        }

        self.setObject(deviceID, forKey:PreferenceDataStore.deviceIDKey)
        return restored
    }()

    @objc
    public init(appKey: String) {
        self.defaults = PreferenceDataStore.createDefaults(appKey: appKey)
        self.appKey = appKey
        super.init()
        mergeKeys()
    }
    
    class func createDefaults(appKey: String) -> UserDefaults {
        let suiteName = "\(Bundle.main.bundleIdentifier ?? "").airship.settings"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            AirshipLogger.error("Failed to create defaults \(suiteName)")
            return UserDefaults.standard
        }
        
        let legacyPrefix = legacyKeyPrefix(appKey: appKey)
        for (key, value) in UserDefaults.standard.dictionaryRepresentation() {
            if key.hasPrefix(appKey) || key.hasPrefix(legacyPrefix) {
                defaults.setValue(value, forKey: key)
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        
        return defaults
    }
    
    func prefixKey(_ key: String) -> String {
        return (appKey) + key
    }

    @objc
    public override func value(forKey key: String) -> Any? {
        return defaults.value(forKey: prefixKey(key))
    }

    @objc
    public override func setValue(_ value: Any?, forKey key: String) {
        defaults.setValue(value, forKey: prefixKey(key))
    }

    @objc
    public func removeObject(forKey key: String) {
        defaults.removeObject(forKey: prefixKey(key))
    }

    @objc
    public func keyExists(_ key: String) -> Bool {
        return object(forKey: key) != nil
    }

    @objc
    public func object(forKey key: String) -> Any? {
        return defaults.object(forKey: prefixKey(key))
    }

    @objc
    public func string(forKey key: String) -> String? {
        return defaults.string(forKey: prefixKey(key))
    }

    @objc
    public func array(forKey key: String) -> [AnyHashable]? {
        return defaults.array(forKey: prefixKey(key)) as? [AnyHashable]
    }

    @objc
    public func dictionary(forKey key: String) -> [AnyHashable : Any]? {
        return defaults.dictionary(forKey: prefixKey(key))
    }

    @objc
    public func data(forKey key: String) -> Data? {
        return defaults.data(forKey: prefixKey(key))
    }

    @objc
    public func stringArray(forKey key: String) -> [AnyHashable]? {
        return defaults.stringArray(forKey: prefixKey(key))
    }

    @objc
    public func integer(forKey key: String) -> Int {
        return defaults.integer(forKey: prefixKey(key))
    }

    @objc
    public func float(forKey key: String) -> Float {
        return defaults.float(forKey: prefixKey(key))
    }

    @objc
    public func double(forKey key: String) -> Double {
        return defaults.double(forKey: prefixKey(key))
    }

    @objc
    public func double(forKey key: String, defaultValue: Double) -> Double {
        if (keyExists(key)) {
            return double(forKey: key)
        } else {
            return defaultValue
        }
    }

    @objc
    public func bool(forKey key: String) -> Bool {
        return defaults.bool(forKey: prefixKey(key))
    }

    @objc
    public func bool(forKey key: String, defaultValue: Bool) -> Bool {
        if keyExists(key) {
            return bool(forKey: key)
        } else {
            return defaultValue
        }
    }

    @objc
    public func url(forKey key: String) -> URL? {
        return defaults.url(forKey: prefixKey(key))
    }

    @objc
    public func setInteger(_ int: Int, forKey key: String) {
        defaults.set(int, forKey: prefixKey(key))
    }

    @objc
    public func setFloat(_ float: Float, forKey key: String) {
        defaults.set(float, forKey: prefixKey(key))
    }

    @objc
    public func setDouble(_ double: Double, forKey key: String) {
        defaults.set(double, forKey: prefixKey(key))
    }

    @objc
    public func setBool(_ bool: Bool, forKey key: String) {
        defaults.set(bool, forKey: prefixKey(key))
    }

    @objc
    public func setURL(_ url: URL?, forKey key: String) {
        defaults.set(url, forKey: prefixKey(key))
    }

    @objc
    public func setObject(_ object: Any?, forKey key: String) {
        defaults.set(object, forKey: prefixKey(key))
    }
    
    /// Merges old key formats `com.urbanairship.<APP_KEY>.<PREFERENCE>` to
    /// the new key formats `<APP_KEY><PREFERENCE>`. Fixes a bug in SDK 15.x-16.0.1
    /// where the key changed but we didnt migrate the data.
    private func mergeKeys() {
        let legacyKeyPrefix = PreferenceDataStore.legacyKeyPrefix(appKey: self.appKey)
        
        for (key, value) in self.defaults.dictionaryRepresentation() {
            
            // Check for old key
            if key.hasPrefix(legacyKeyPrefix) {

                let preference = String(key.dropFirst(legacyKeyPrefix.count))
                let newValue = object(forKey: preference)
                
                if (newValue == nil) {
                    // Value not updated on new key, restore value
                    setObject(value, forKey: preference)
                } else if (preference == "com.urbanairship.channel.tags") {
                    
                    // Both old and new tag keys have data, merge
                    if let old = value as? [String], let new = newValue as? [String] {
                        let combined = AudienceUtils.normalizeTags(old + new)
                        setObject(combined, forKey: preference)
                    }
                }
                
                // Delete the old key
                self.defaults.removeObject(forKey: key)
            }
        }
    }
    
    private class func legacyKeyPrefix(appKey: String) -> String {
        return "com.urbanairship.\(appKey)."
    }
}
