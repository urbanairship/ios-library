/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable
@_spi(AirshipInternal) import AirshipCore
@_spi(AirshipInternal) import AirshipBasement

@Suite struct AirshipCacheTest {

    private let date = UATestDate(offset: 0, dateOverride: Date())
    private let coreData: UACoreData = CoreDataAirshipCache.makeCoreData(
        appKey: UUID().uuidString,
        inMemory: true
    )!
    private let cache: CoreDataAirshipCache

    init() {
        self.cache = CoreDataAirshipCache(
            coreData: coreData,
            appVersion: "some-app-version",
            sdkVersion: "some-sdk-version",
            date: self.date
        )
    }

    @Test
    func testCacheTTL() async throws {
        await self.cache.setCachedValue("cache value", key: "some key", ttl: 10.0)
        var value: String? = await self.cache.getCachedValue(key: "some key")
        #expect("cache value" == value)

        date.offset += 9.9
        value = await self.cache.getCachedValue(key: "some key")
        #expect("cache value" == value)

        date.offset += 0.1
        value = await self.cache.getCachedValue(key: "some key")
        #expect(value == nil)
    }

    @Test
    func testCacheNil() async throws {
        await self.cache.setCachedValue("cache value", key: "some key", ttl: 10.0)
        var value: String? = await self.cache.getCachedValue(key: "some key")
        #expect("cache value" == value)

        value = nil
        await self.cache.setCachedValue(value, key: "some key", ttl: 10.0)
        #expect(value == nil)
    }

    @Test
    func testOverwriteCache() async throws {
        await self.cache.setCachedValue("cache value", key: "some key", ttl: 10.0)
        await self.cache.setCachedValue("some other cache value", key: "some key", ttl: 10.0)

        let value: String? = await self.cache.getCachedValue(key: "some key")
        #expect("some other cache value" == value)
    }

    @Test
    func testCache() async throws {
        await self.cache.setCachedValue("some value", key: "some key", ttl: 10.0)
        await self.cache.setCachedValue("some other value", key: "some other key", ttl: 10.0)

        var value: String? = await self.cache.getCachedValue(key: "some key")
        #expect("some value" == value)

        value = await self.cache.getCachedValue(key: "some other key")
        #expect("some other value" == value)

        value = await self.cache.getCachedValue(key: "some null key")
        #expect(value == nil)
    }

    @Test
    func testOverwriteCacheClearedSDKVersionChange() async throws {
        await self.cache.setCachedValue("cache value", key: "some key", ttl: 10.0)

        let newCache = CoreDataAirshipCache(
            coreData: coreData,
            appVersion: "some-app-version",
            sdkVersion: "some-other-sdk-version",
            date: self.date
        )

        let value: String? = await newCache.getCachedValue(key: "some key")
        #expect(value == nil)
    }

    @Test
    func testOverwriteCacheClearedAppVersionChange() async throws {
        await self.cache.setCachedValue("cache value", key: "some key", ttl: 10.0)

        let newCache = CoreDataAirshipCache(
            coreData: coreData,
            appVersion: "some-other-app-version",
            sdkVersion: "some-sdk-version",
            date: self.date
        )

        let value: String? = await newCache.getCachedValue(key: "some key")
        #expect(value == nil)
    }
}

public enum TestAirshipCoreDataCache {
    static func makeCache(date: AirshipDateProtocol) -> AirshipCache {
        return CoreDataAirshipCache(
            coreData: CoreDataAirshipCache.makeCoreData(appKey: UUID().uuidString)!,
            appVersion: "version",
            sdkVersion: "sdk",
            date: date
        )
    }
}
