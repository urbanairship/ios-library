/* Copyright Airship and Contributors */

import Foundation

/// Preference data store.
/// - Note: For internal use only. :nodoc:
@objc(UAPreferenceDataStore)
public class PreferenceDataStore: NSObject {
    private let defaults: UserDefaults
    private let appKey: String
    static let deviceIDKey = "deviceID"

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    
    private var pending: [String: [Any?]] = [:]
    private var cache: [String: Cached] = [:]
    private let lock = AirshipLock()
    private let dispatcher: UADispatcher
    private var keychainAccess: PreferenceDataStoreKeychainAccessProtocol

    lazy var isAppRestore: Bool = {
        var deviceID = self.keychainAccess.deviceID
        if (deviceID == nil) {
            deviceID = UUID().uuidString
            self.keychainAccess.deviceID = deviceID
        }
        
        let previousDeviceID = self.string(forKey: PreferenceDataStore.deviceIDKey)
        if (deviceID == previousDeviceID) {
            return false
        }

        var restored = previousDeviceID != nil
        if restored {
            AirshipLogger.info("App restored")
        }

        self.setObject(deviceID, forKey: PreferenceDataStore.deviceIDKey)
        return restored
    }()

    @objc
    public convenience init(appKey: String) {
        self.init(
            appKey: appKey,
            dispatcher: UADispatcher.serial(),
            keychainAccess: AirshipKeychainAccess(appKey: appKey)
        )
    }

    init(appKey: String, dispatcher: UADispatcher, keychainAccess: PreferenceDataStoreKeychainAccessProtocol) {
        self.defaults = PreferenceDataStore.createDefaults(appKey: appKey)
        self.appKey = appKey
        self.dispatcher = dispatcher
        self.keychainAccess = keychainAccess
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
                defaults.set(value, forKey: key)
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        return defaults
    }

    @objc
    public override func value(forKey key: String) -> Any? {
        return read(key)
    }

    @objc
    public override func setValue(_ value: Any?, forKey key: String) {
        write(key, value: value)
    }

    func storeValue(_ value: Any?, forKey key: String) {
        write(key, value: value)
    }

    @objc
    public func removeObject(forKey key: String) {
        write(key, value: nil)
    }

    @objc
    public func keyExists(_ key: String) -> Bool {
        return object(forKey: key) != nil
    }

    @objc
    public func object(forKey key: String) -> Any? {
        return read(key)
    }

    @objc
    public func string(forKey key: String) -> String? {
        return read(key)
    }

    @objc
    public func array(forKey key: String) -> [AnyHashable]? {
        return read(key)
    }

    @objc
    public func dictionary(forKey key: String) -> [AnyHashable: Any]? {
        return read(key)
    }

    @objc
    public func data(forKey key: String) -> Data? {
        return read(key)
    }

    @objc
    public func stringArray(forKey key: String) -> [AnyHashable]? {
        return read(key)
    }

    @objc
    public func integer(forKey key: String) -> Int {
        return read(key) ?? 0
    }

    public func unsignedInteger(forKey key: String) -> UInt? {
        return read(key)
    }
    

    @objc
    public func float(forKey key: String) -> Float {
        return read(key) ?? 0.0
    }

    @objc
    public func double(forKey key: String) -> Double {
        return read(key) ?? 0.0
    }

    @objc
    public func double(forKey key: String, defaultValue: Double) -> Double {
        return read(key, defaultValue: defaultValue)
    }

    @objc
    public func bool(forKey key: String) -> Bool {
        return read(key) ?? false
    }

    @objc
    public func bool(forKey key: String, defaultValue: Bool) -> Bool {
        return read(key, defaultValue: defaultValue)
    }

    @objc
    public func setInteger(_ int: Int, forKey key: String) {
        write(key, value: int)
    }

    public func setUnsignedInteger(_ value: UInt, forKey key: String) {
        write(key, value: value)
    }

    @objc
    public func setFloat(_ float: Float, forKey key: String) {
        write(key, value: float)
    }

    @objc
    public func setDouble(_ double: Double, forKey key: String) {
        write(key, value: double)
    }

    @objc
    public func setBool(_ bool: Bool, forKey key: String) {
        write(key, value: bool)
    }

    @objc
    public func setObject(_ object: Any?, forKey key: String) {
        write(key, value: object)
    }

    public func codable<T: Codable>(forKey key: String) throws -> T? {
        guard let data: Data = read(key) else {
            return nil
        }

        return try decoder.decode(T.self, from: data)
    }

    public func setCodable<T: Codable>(
        _ codable: T?,
        forKey key: String
    ) throws {
        guard let codable = codable else {
            write(key, value: nil)
            return
        }

        let data = try encoder.encode(codable)
        write(key, value: data)
    }

    /// Merges old key formats `com.urbanairship.<APP_KEY>.<PREFERENCE>` to
    /// the new key formats `<APP_KEY><PREFERENCE>`. Fixes a bug in SDK 15.x-16.0.1
    /// where the key changed but we didnt migrate the data.
    private func mergeKeys() {
        let legacyKeyPrefix = PreferenceDataStore.legacyKeyPrefix(
            appKey: self.appKey
        )

        for (key, value) in self.defaults.dictionaryRepresentation() {

            // Check for old key
            if key.hasPrefix(legacyKeyPrefix) {

                let preference = String(key.dropFirst(legacyKeyPrefix.count))
                let newValue = object(forKey: preference)

                if newValue == nil {
                    // Value not updated on new key, restore value
                    setObject(value, forKey: preference)
                } else if preference == "com.urbanairship.channel.tags" {

                    // Both old and new tag keys have data, merge
                    if let old = value as? [String],
                        let new = newValue as? [String]
                    {
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

    private func read<T>(_ key: String, defaultValue: T) -> T {
        return read(key) ?? defaultValue
    }

    private func read<T>(_ key: String) -> T? {
        let key = prefixKey(key)
        let defaults = self.defaults
        var result: Any?

        lock.sync {
            if let cached = self.cache[key] {
                result = cached.value
            } else {
                result = defaults.object(forKey: key)
            }
        }

        guard let result = result else {
            return nil
        }

        return result as? T
    }

    func write(_ key: String, value: Any?) {
        let key = prefixKey(key)
        let value = value

        lock.sync {
            self.cache[key] = Cached(value: value)
        }

        self.dispatcher.dispatchAsync {
            self.lock.sync {
                if let value = self.cache[key]?.value {
                    self.defaults.set(value, forKey: key)
                } else {
                    self.defaults.removeObject(forKey: key)
                }
            }
        }
    }

    private func prefixKey(_ key: String) -> String {
        return (appKey) + key
    }
}


private struct Cached {
    let value: Any?
}


protocol PreferenceDataStoreKeychainAccessProtocol {
    var deviceID: String? { get set }
}

extension AirshipKeychainAccess : PreferenceDataStoreKeychainAccessProtocol {
    private static let deviceKeychainID = "com.urbanairship.deviceID"
    var deviceID: String? {
        get {
            self.readCredentialsSync(
                identifier: AirshipKeychainAccess.deviceKeychainID
            )?.password
        }
        set {
            if let newValue = newValue {
                self.writeCredentials(
                    AirshipKeychainCredentials(
                        username: "airship",
                        password: newValue
                    ),
                    identifier:  AirshipKeychainAccess.deviceKeychainID
                ) { result in
                    if (!result) {
                        AirshipLogger.error("Unable to save device ID")
                    }
                }
            } else {
                self.deleteCredentials(
                    identifier: AirshipKeychainAccess.deviceKeychainID
                )
            }
            
        }
    }
    
}
