/* Copyright Airship and Contributors */

/**
 * Preference data store.
 * @note For internal use only. :nodoc:
 */
@objc
public class UAPreferenceDataStore : NSObject {
    private let defaults: UserDefaults
    private let keyPrefix: String

    @objc
    public init(keyPrefix: String) {
        self.defaults = UAPreferenceDataStore.createDefaults(keyPrefix: keyPrefix)
        self.keyPrefix = keyPrefix
        super.init()
    }
    
    class func createDefaults(keyPrefix: String) -> UserDefaults {
        let suiteName = "\(Bundle.main.bundleIdentifier ?? "").airship.settings"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            AirshipLogger.error("Failed to create defaults \(suiteName)")
            return UserDefaults.standard
        }
        
        for (key, value) in UserDefaults.standard.dictionaryRepresentation() {
            if key.hasPrefix(keyPrefix) {
                defaults.setValue(value, forKey: key)
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        
        return defaults
    }
    
    func prefixKey(_ key: String) -> String {
        return (keyPrefix) + key
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

    @objc
    func removeAll() {
        for key in defaults.dictionaryRepresentation().keys {
            if key.hasPrefix(keyPrefix) {
                defaults.removeObject(forKey: key)
            }
        }
    }
}
