import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

final class PersistantStore<T: Codable&Sendable>: Sendable {

    private let dataStore: PreferenceDataStore
    private let prefix: String

    init(dataStore: PreferenceDataStore, prefix: String) {
        self.dataStore = dataStore
        self.prefix = prefix
    }

    public func setValue(_ value: T?, forKey key: String) {
        self.dataStore.setSafeCodable(value, forKey: prefixKey(key))
    }

    public func value(forKey key: String) -> T? {
        return self.dataStore.safeCodable(forKey: prefixKey(key))
    }

    private func prefixKey(_ key: String) -> String {
        return "\(prefix)\(key)"
    }
}
