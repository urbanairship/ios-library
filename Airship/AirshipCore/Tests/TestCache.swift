
/* Copyright Airship and Contributors */



@testable
import AirshipCore

struct CacheEntry: Sendable {
    let data: Data
    let ttl: TimeInterval
}

actor TestCache: AirshipCache {
    func deleteCachedValue(key: String) async {
        values[key] = nil
    }

    private var values: [String: CacheEntry] = [:]

    func entry(key: String) async -> CacheEntry? {
        return self.values[key]
    }

    func getCachedValue<T>(key: String) async -> T? where T : Decodable, T : Encodable, T : Sendable {
        guard let value = self.values[key] else {
            return nil
        }

        return try? JSONDecoder().decode(T.self, from: value.data)
    }

    func setCachedValue<T>(
        _ value: T?,
        key: String,
        ttl: TimeInterval
    ) async where T : Decodable, T : Encodable, T : Sendable {
        guard let value = value, let data = try? JSONEncoder().encode(value) else {
            return
        }

        self.values[key] = CacheEntry(data: data, ttl: ttl)
    }

}
