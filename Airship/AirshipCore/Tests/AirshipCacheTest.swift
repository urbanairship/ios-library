/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

final class AirshipCacheTest: XCTestCase {

    private let date = UATestDate(offset: 0, dateOverride: Date())
    private let coreData: UACoreData = CoreDataAirshipCache.makeCoreData(appKey: "some-app-key")!
    private var cache: CoreDataAirshipCache!

    override func setUpWithError() throws {
        self.cache = CoreDataAirshipCache(
            coreData: coreData,
            appVersion: "some-app-version",
            sdkVersion: "some-sdk-version",
            date: self.date
        )
    }

    func testCacheTTL() async throws {
        await self.cache.setCachedValue("cache value", key: "some key", ttl: 10.0)
        var value: String? = await self.cache.getCachedValue(key: "some key")
        XCTAssertEqual("cache value", value)

        date.offset += 9.9
        value = await self.cache.getCachedValue(key: "some key")
        XCTAssertEqual("cache value", value)

        date.offset += 0.1
        value = await self.cache.getCachedValue(key: "some key")
        XCTAssertNil(value)
    }

    func testCacheNil() async throws {
        await self.cache.setCachedValue("cache value", key: "some key", ttl: 10.0)
        var value: String? = await self.cache.getCachedValue(key: "some key")
        XCTAssertEqual("cache value", value)

        value = nil
        await self.cache.setCachedValue(value, key: "some key", ttl: 10.0)
        XCTAssertNil(value)
    }

    func testOverwriteCache() async throws {
        await self.cache.setCachedValue("cache value", key: "some key", ttl: 10.0)
        await self.cache.setCachedValue("some other cache value", key: "some key", ttl: 10.0)

        let value: String? = await self.cache.getCachedValue(key: "some key")
        XCTAssertEqual("some other cache value", value)
    }

    func testCache() async throws {
        await self.cache.setCachedValue("some value", key: "some key", ttl: 10.0)
        await self.cache.setCachedValue("some other value", key: "some other key", ttl: 10.0)

        var value: String? = await self.cache.getCachedValue(key: "some key")
        XCTAssertEqual("some value", value)

        value = await self.cache.getCachedValue(key: "some other key")
        XCTAssertEqual("some other value", value)

        value = await self.cache.getCachedValue(key: "some null key")
        XCTAssertNil(value)
    }

    func testOverwriteCacheClearedSDKVersionChange() async throws {
        await self.cache.setCachedValue("cache value", key: "some key", ttl: 10.0)

        self.cache = CoreDataAirshipCache(
            coreData: coreData,
            appVersion: "some-app-version",
            sdkVersion: "some-other-sdk-version",
            date: self.date
        )

        let value: String? = await self.cache.getCachedValue(key: "some key")
        XCTAssertNil(value)
    }

    func testOverwriteCacheClearedAppVersionChange() async throws {
        await self.cache.setCachedValue("cache value", key: "some key", ttl: 10.0)

        self.cache = CoreDataAirshipCache(
            coreData: coreData,
            appVersion: "some-other-app-version",
            sdkVersion: "some-sdk-version",
            date: self.date
        )

        let value: String? = await self.cache.getCachedValue(key: "some key")
        XCTAssertNil(value)
    }
}

