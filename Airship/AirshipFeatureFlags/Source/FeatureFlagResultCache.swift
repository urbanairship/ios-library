/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Feature Flag result cache
public actor FeatureFlagResultCache {
    private static let cacheKeyPrefix: String = "FeatureFlagResultCache:"
    private let cache: any AirshipCache

    init(cache: any AirshipCache) {
        self.cache = cache
    }

    /// Caches a flag for the given cachTTL.
    /// - Parameters:
    ///     - flag: The flag to cache
    ///     - ttl: The time to cache the value for.
    public func cacheFlag(flag: FeatureFlag, ttl: TimeInterval) async {
        guard let key = Self.makeKey(flag.name) else {
            return
        }

        await cache.setCachedValue(flag, key: key, ttl: ttl)
    }

    /// Gets a flag from the cache.
    /// - Parameters:
    ///     - name: The flag name.
    /// - Returns: The flag if its in the cache, otherwise nil.
    public func flag(name: String) async -> FeatureFlag? {
        guard let key = Self.makeKey(name) else {
            return nil
        }
        return await cache.getCachedValue(key: key)
    }

    /// Removes a flag from the cache.
    /// - Parameters:
    ///     - name: The flag name.
    public func removeCachedFlag(name: String) async {
        guard let key = Self.makeKey(name) else {
            return
        }

        return await cache.deleteCachedValue(key: key)
    }

    private static func makeKey(_ name: String) -> String? {
        guard !name.isEmpty else {
            AirshipLogger.error("Flag cache key is empty.")
            return nil
        }
        return "\(cacheKeyPrefix)\(name)"
    }
}
