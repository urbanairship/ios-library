/* Copyright Airship and Contributors */

public import Foundation
@_spi(AirshipInternal) import AirshipBasement

/// Preference data store.
/// - Note: For internal use only. :nodoc:
public final class PreferenceDataStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let appKey: String
    static let deviceIDKey: String = "deviceID"
    
    private var pending: [String: [Any?]] = [:]
    private var cache: [String: Cached] = [:]
    private let lock: AirshipLock = AirshipLock()
    private let queue: DispatchQueue
    private var deviceID: any AirshipDeviceIDProtocol

    var isAppRestore: Bool {
        get async {
            let deviceIDValue = await deviceID.value

            var restored: Bool = false
            lock.sync {
                let previousDeviceID: String? = self.readLocked(PreferenceDataStore.deviceIDKey)
                if (deviceIDValue != previousDeviceID) {
                    restored = previousDeviceID != nil
                    self.writeLocked(PreferenceDataStore.deviceIDKey, value: deviceIDValue)
                }
            }

            if (restored) {
                AirshipLogger.info("App restored")
            }
            return restored
        }
    }

    public convenience init(appKey: String) {
        self.init(
            appKey: appKey,
            deviceID: AirshipDeviceID(appKey: appKey)
        )
    }

    init(appKey: String, deviceID: any AirshipDeviceIDProtocol) {
        self.defaults = PreferenceDataStore.createDefaults()
        self.appKey = appKey
        self.queue = DispatchQueue(
            label: "com.urbanairship.preferencedatastore.serial_queue"
        )
        self.deviceID = deviceID
        migrateLegacyKeysIfNeeded()
    }

    class func createDefaults() -> UserDefaults {
        let suiteName = "\(Bundle.main.bundleIdentifier ?? "").airship.settings"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            AirshipLogger.error("Failed to create defaults \(suiteName)")
            return UserDefaults.standard
        }

        return defaults
    }

    public func value(forKey key: String) -> Any? {
        return read(key)
    }

    public func setValue(_ value: Any?, forKey key: String) {
        write(key, value: value)
    }

    func storeValue(_ value: Any?, forKey key: String) {
        write(key, value: value)
    }

    @objc
    public func removeObject(forKey key: String) {
        write(key, value: nil)
    }

    public func keyExists(_ key: String) -> Bool {
        return object(forKey: key) != nil
    }

    @objc
    public func object(forKey key: String) -> Any? {
        return read(key)
    }

    public func string(forKey key: String) -> String? {
        return read(key)
    }

    public func array(forKey key: String) -> [AnyHashable]? {
        return read(key)
    }

    public func dictionary(forKey key: String) -> [AnyHashable: Any]? {
        return read(key)
    }

    public func data(forKey key: String) -> Data? {
        return read(key)
    }

    public func stringArray(forKey key: String) -> [AnyHashable]? {
        return read(key)
    }

    public func integer(forKey key: String) -> Int {
        return read(key) ?? 0
    }

    public func unsignedInteger(forKey key: String) -> UInt? {
        return read(key)
    }

    public func float(forKey key: String) -> Float {
        return read(key) ?? 0.0
    }

    public func double(forKey key: String) -> Double {
        return read(key) ?? 0.0
    }

    public func double(forKey key: String, defaultValue: Double) -> Double {
        return read(key, defaultValue: defaultValue)
    }

    @objc
    public func bool(forKey key: String) -> Bool {
        return read(key) ?? false
    }

    public func bool(forKey key: String, defaultValue: Bool) -> Bool {
        return read(key, defaultValue: defaultValue)
    }

    public func setInteger(_ int: Int, forKey key: String) {
        write(key, value: int)
    }

    public func setUnsignedInteger(_ value: UInt, forKey key: String) {
        write(key, value: value)
    }

    public func setFloat(_ float: Float, forKey key: String) {
        write(key, value: float)
    }

    public func setDouble(_ double: Double, forKey key: String) {
        write(key, value: double)
    }

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

        return try JSONDecoder().decode(T.self, from: data)
    }

    public func safeCodable<T: Codable>(forKey key: String) -> T? {
        do {
            return try codable(forKey: key)
        } catch {
            AirshipLogger.error("Failed to read codable for key \(key)")
            return nil
        }
    }

    public func setSafeCodable<T: Codable>(
        _ codable: T?,
        forKey key: String
    ) {
        do {
            try setCodable(codable, forKey: key)
        } catch {
            AirshipLogger.error("Failed to write codable for key \(key)")
        }
    }

    public func setCodable<T: Codable>(
        _ codable: T?,
        forKey key: String
    ) throws {
        guard let codable = codable else {
            write(key, value: nil)
            return
        }

        let data = try JSONEncoder().encode(codable)
        write(key, value: data)
    }

    /// Repairs the key-format bug from SDK 15.x-16.0.1, where the key changed but
    /// we didn't migrate the data. Both steps below are one-time repairs, so they
    /// run once per app key and are skipped on every launch after that.
    ///
    /// The completion flag is written through `write` like any other value, so it
    /// queues behind the migration's own writes on the serial queue. If the app
    /// dies before those flush, the flag doesn't persist either and the migration
    /// is retried on the next launch rather than being lost.
    private func migrateLegacyKeysIfNeeded() {
        let completedKey = PreferenceDataStore.legacyKeyMigrationCompletedKey
        guard !bool(forKey: completedKey) else {
            return
        }

        migrateStandardDefaultsKeys()
        mergeKeys()

        setBool(true, forKey: completedKey)
    }

    /// Moves Airship keys that SDK 15.x-16.0.1 wrote to the standard defaults into
    /// the Airship suite.
    ///
    /// Scoped to the app's own preferences domain rather than
    /// `dictionaryRepresentation()`, which also exposes `NSGlobalDomain`, managed
    /// configuration and registered defaults. We never wrote to any of those, and
    /// `removeObject(forKey:)` can't remove from them either.
    private func migrateStandardDefaultsKeys() {
        let standardDefaults = UserDefaults.standard

        let appDomain: [String: Any]
        if let domainName = Bundle.main.bundleIdentifier,
            let domain = standardDefaults.persistentDomain(forName: domainName)
        {
            appDomain = domain
        } else {
            // No bundle identifier, so there is no app domain to scope to.
            appDomain = standardDefaults.dictionaryRepresentation()
        }

        let legacyPrefix = PreferenceDataStore.legacyKeyPrefix(
            appKey: self.appKey
        )

        for (key, value) in appDomain {
            if key.hasPrefix(self.appKey) || key.hasPrefix(legacyPrefix) {
                self.defaults.set(value, forKey: key)
                standardDefaults.removeObject(forKey: key)
            }
        }
    }

    /// Merges old key formats `com.urbanairship.<APP_KEY>.<PREFERENCE>` to
    /// the new key formats `<APP_KEY><PREFERENCE>`.
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

    /// Records that the legacy key migration has run. `prefixKey` prepends the app
    /// key, so each app key is migrated exactly once.
    private static let legacyKeyMigrationCompletedKey =
        "com.urbanairship.preference_data_store.legacy_key_migration_completed"

    private func read<T>(_ key: String, defaultValue: T) -> T {
        return read(key) ?? defaultValue
    }

    private func read<T>(_ key: String) -> T? {
        return lock.sync {
            self.readLocked(key)
        }
    }

    /// Caller must hold `lock`.
    private func readLocked<T>(_ key: String) -> T? {
        let key = prefixKey(key)
        let result: Any?
        if let cached = self.cache[key] {
            result = cached.value
        } else {
            result = self.defaults.object(forKey: key)
        }

        guard let result = result else {
            return nil
        }

        return result as? T
    }

    func write(_ key: String, value: Any?) {
        lock.sync {
            self.writeLocked(key, value: value)
        }
    }

    /// Caller must hold `lock`.
    private func writeLocked(_ key: String, value: Any?) {
        let key = prefixKey(key)

        self.cache[key] = Cached(value: value)

        self.queue.async {
            self.lock.sync {
                if let value = self.cache[key]?.value {
                    self.defaults.set(value, forKey: key)
                } else {
                    self.defaults.removeObject(forKey: key)
                }
            }
        }
    }

    /// Waits for any pending writes to be flushed to the underlying defaults.
    /// - Note: For internal/testing use only. :nodoc:
    func waitForWrites() {
        self.queue.sync {}
    }

    private func prefixKey(_ key: String) -> String {
        return (appKey) + key
    }
}


private struct Cached {
    let value: Any?
}
