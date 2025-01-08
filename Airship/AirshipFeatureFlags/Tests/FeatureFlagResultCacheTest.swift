/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

@testable
import AirshipFeatureFlags

final class FeatureFlagResultCacheTest: XCTestCase {
    private let airshipCache: TestCache = TestCache()
    private var resultCache: FeatureFlagResultCache!

    override func setUp() {
        self.resultCache = FeatureFlagResultCache(cache: self.airshipCache)
    }

    public func testSet() async {
        let flag = FeatureFlag(name: UUID().uuidString, isEligible: true, exists: true)
        await resultCache.cache(flag: flag, ttl: 100)

        let entry = await airshipCache.entry(key: "FeatureFlagResultCache:\(flag.name)")!
        XCTAssertEqual(
            try JSONDecoder().decode(FeatureFlag.self, from: entry.data),
            flag
        )
        XCTAssertEqual(entry.ttl, 100)
    }

    public func testUpdate() async {
        var flag = FeatureFlag(name: UUID().uuidString, isEligible: true, exists: true)
        await resultCache.cache(flag: flag, ttl: 100)
        flag.isEligible = false
        await resultCache.cache(flag: flag, ttl: 99)

        let entry = await airshipCache.entry(key: "FeatureFlagResultCache:\(flag.name)")!
        XCTAssertEqual(
            try JSONDecoder().decode(FeatureFlag.self, from: entry.data),
            flag
        )
        XCTAssertEqual(entry.ttl, 99)
    }

    public func testDeleteDoesNotExist() async {
        await resultCache.removeCachedFlag(name: "does not exist")
    }

    public func testDelete() async {
        let flag = FeatureFlag(name: UUID().uuidString, isEligible: true, exists: true)
        await resultCache.cache(flag: flag, ttl: 100)
        var entry = await airshipCache.entry(key: "FeatureFlagResultCache:\(flag.name)")
        XCTAssertNotNil(entry)

        await resultCache.removeCachedFlag(name: flag.name)
        entry = await airshipCache.entry(key: "FeatureFlagResultCache:\(flag.name)")
        XCTAssertNil(entry)
    }
}
