/* Copyright Airship and Contributors */

import Foundation

struct HashChecker {
    private let queue = AirshipSerialQueue()
    private let cache: any AirshipCache

    init(cache: any AirshipCache) {
        self.cache = cache
    }

    func evaluate(
        hashSelector: AudienceHashSelector?,
        deviceInfoProvider: any AudienceDeviceInfoProvider
    ) async throws -> AirshipDeviceAudienceResult {
        guard let hashSelector else {
            return .match
        }

        return try await self.queue.run {
            let contactID = await deviceInfoProvider.stableContactInfo.contactID
            let channelID = try await deviceInfoProvider.channelID

            let result = await self.resolveResult(
                hashSelector: hashSelector,
                contactID: contactID,
                channelID: channelID
            )

            await self.cacheResult(
                selector: hashSelector,
                result: result,
                contactID: contactID,
                channelID: channelID
            )

            return result
        }
    }

    private func resolveResult(
        hashSelector: AudienceHashSelector,
        contactID: String,
        channelID: String
    ) async -> AirshipDeviceAudienceResult {
        guard
            let cached = await self.getCachedResult(
                selector: hashSelector,
                contactID: contactID,
                channelID: channelID
            )
        else {
            let isMatch = hashSelector.evaluate(
                channelID: channelID,
                contactID: contactID
            )

            let reportingMetadata: [AirshipJSON]? = if let reporting = hashSelector.sticky?.reportingMetadata {
                [reporting]
            } else {
                nil
            }

            return AirshipDeviceAudienceResult(
                isMatch: isMatch,
                reportingMetadata: reportingMetadata
            )
        }

        return cached
    }

    private func cacheResult(
        selector: AudienceHashSelector,
        result: AirshipDeviceAudienceResult,
        contactID: String,
        channelID: String
    ) async {
        guard let sticky = selector.sticky else {
            return
        }

        let key = Self.makeCacheKey(
            sticky.id,
            contactID: contactID,
            channelID: channelID
        )

        await cache.setCachedValue(result, key: key, ttl: sticky.lastAccessTTL)
    }

    private func getCachedResult(
        selector: AudienceHashSelector,
        contactID: String,
        channelID: String
    ) async -> AirshipDeviceAudienceResult? {
        guard let sticky = selector.sticky else {
            return nil
        }

        let key = Self.makeCacheKey(
            sticky.id,
            contactID: contactID,
            channelID: channelID
        )

        return await cache.getCachedValue(key: key)
    }

    private static func makeCacheKey(
        _ id: String,
        contactID: String,
        channelID: String
    ) -> String {
        return "StickyHash:\(contactID):\(channelID):\(id)"
    }
}
