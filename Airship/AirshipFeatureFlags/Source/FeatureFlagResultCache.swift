/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Feature Flag result cache
public protocol FeatureFlagResultCache: Actor {
    /// Caches a flag for the given cachTTL.
    /// - Parameters:
    ///     - flag: The flag to cache
    ///     - ttl: The time to cache the value for.
    func cache(flag: FeatureFlag, ttl: TimeInterval) async

    /// Gets a flag from the cache.
    /// - Parameters:
    ///     - name: The flag name.
    /// - Returns: The flag if its in the cache, otherwise nil.
    func flag(name: String) async -> FeatureFlag?

    /// Removes a flag from the cache.
    /// - Parameters:
    ///     - name: The flag name.
    func removeCachedFlag(name: String) async
}

actor DefaultFeatureFlagResultCache: FeatureFlagResultCache {
    private static let cacheKeyPrefix: String = "FeatureFlagResultCache:"
    private let airshipCache: any AirshipCache

    init(cache: any AirshipCache) {
        self.airshipCache = cache
    }

    func cache(flag: FeatureFlag, ttl: TimeInterval) async {
        guard let key = Self.makeKey(flag.name) else {
            return
        }

        await airshipCache.setCachedValue(flag, key: key, ttl: ttl)
    }

    func flag(name: String) async -> FeatureFlag? {
        guard let key = Self.makeKey(name) else {
            return nil
        }
        return await airshipCache.getCachedValue(key: key)
    }

    func removeCachedFlag(name: String) async {
        guard let key = Self.makeKey(name) else {
            return
        }

        return await airshipCache.deleteCachedValue(key: key)
    }

    private static func makeKey(_ name: String) -> String? {
        guard !name.isEmpty else {
            AirshipLogger.error("Flag cache key is empty.")
            return nil
        }
        return "\(cacheKeyPrefix)\(name)"
    }
}
