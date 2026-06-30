/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable
import AirshipCore

@testable
import AirshipFeatureFlags

struct FeatureFlagResultCacheTest {
    private let airshipCache: TestCache = TestCache()
    private let resultCache: DefaultFeatureFlagResultCache

    init() {
        self.resultCache = DefaultFeatureFlagResultCache(cache: self.airshipCache)
    }

    @Test
    func testSet() async throws {
        let flag = FeatureFlag(name: UUID().uuidString, isEligible: true, exists: true)
        await resultCache.cache(flag: flag, ttl: 100)

        let entry = await airshipCache.entry(key: "FeatureFlagResultCache:\(flag.name)")!
        #expect(
            try JSONDecoder().decode(FeatureFlag.self, from: entry.data) == flag
        )
        #expect(entry.ttl == 100)
    }

    @Test
    func testUpdate() async throws {
        var flag = FeatureFlag(name: UUID().uuidString, isEligible: true, exists: true)
        await resultCache.cache(flag: flag, ttl: 100)
        flag.isEligible = false
        await resultCache.cache(flag: flag, ttl: 99)

        let entry = await airshipCache.entry(key: "FeatureFlagResultCache:\(flag.name)")!
        #expect(
            try JSONDecoder().decode(FeatureFlag.self, from: entry.data) == flag
        )
        #expect(entry.ttl == 99)
    }

    @Test
    func testDeleteDoesNotExist() async {
        await resultCache.removeCachedFlag(name: "does not exist")
    }

    @Test
    func testDelete() async {
        let flag = FeatureFlag(name: UUID().uuidString, isEligible: true, exists: true)
        await resultCache.cache(flag: flag, ttl: 100)
        var entry = await airshipCache.entry(key: "FeatureFlagResultCache:\(flag.name)")
        #expect(entry != nil)

        await resultCache.removeCachedFlag(name: flag.name)
        entry = await airshipCache.entry(key: "FeatureFlagResultCache:\(flag.name)")
        #expect(entry == nil)
    }
}
