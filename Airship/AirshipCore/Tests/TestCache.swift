
/* Copyright Airship and Contributors */

import Foundation

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
        return await getCachedValue(key: key, decoder: AirshipJSON.defaultDecoder)
    }

    func getCachedValue<T>(key: String, decoder: JSONDecoder) async -> T? where T : Decodable, T : Encodable, T : Sendable {
        guard let value = self.values[key] else {
            return nil
        }

        return try? decoder.decode(T.self, from: value.data)
    }

    func setCachedValue<T>(_ value: T?, key: String, ttl: TimeInterval) async where T : Decodable, T : Encodable, T : Sendable {
        return await setCachedValue(value, key: key, ttl: ttl, encoder: AirshipJSON.defaultEncoder)
    }

    func setCachedValue<T>(
        _ value: T?,
        key: String,
        ttl: TimeInterval,
        encoder: JSONEncoder
    ) async where T : Decodable, T : Encodable, T : Sendable {
        guard let value = value, let data = try? encoder.encode(value) else {
            return
        }

        self.values[key] = CacheEntry(data: data, ttl: ttl)
    }

}
