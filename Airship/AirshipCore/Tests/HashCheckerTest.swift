/* Copyright Airship and Contributors */

import Testing
@testable import AirshipCore
import Foundation

@Suite struct HashCheckerTest {
    private let cache: TestCache = TestCache()
    private let testDeviceInfo: TestAudienceDeviceInfoProvider = TestAudienceDeviceInfoProvider()

    private let checker: HashChecker

    init() {
        self.checker = HashChecker(cache: cache)
    }

    @Test
    func testStickyCacheMatch() async throws {
        self.testDeviceInfo.channelID = "some channel"
        self.testDeviceInfo.stableContactInfo = StableContactInfo(contactID: "match")

        let stickyHash = AudienceHashSelector(
            hash: AudienceHashSelector.Hash(
                prefix: "e66a2371-fecf-41de-9238-cb6c28a86cec:",
                property: .contact,
                algorithm: .farm,
                seed: 100,
                numberOfBuckets: 16384,
                overrides: nil
            ),
            bucket: AudienceHashSelector.Bucket(min: 11600, max: 13000),
            sticky: AudienceHashSelector.Sticky(
                id: "sticky ID",
                reportingMetadata: "sticky reporting",
                lastAccessTTL: 100.0
            )
        )


        let result = try await checker.evaluate(
            hashSelector: stickyHash,
            deviceInfoProvider: self.testDeviceInfo
        )

        #expect(
            AirshipDeviceAudienceResult(
                isMatch: true,
                reportingMetadata: [.string("sticky reporting")]
            ) ==
            result
        )

        let entry = await self.cache.entry(key: "StickyHash:match:some channel:sticky ID")!
        #expect(entry.ttl == 100.0)
        let decodedData = try JSONDecoder().decode(AirshipDeviceAudienceResult.self, from: entry.data)
        #expect(decodedData == result)
    }

    @Test
    func testStickyHashFromCacheStillCaches() async throws {
        self.testDeviceInfo.channelID = "some channel"
        self.testDeviceInfo.stableContactInfo = StableContactInfo(contactID: "match")

        var stickyHash = AudienceHashSelector(
            hash: AudienceHashSelector.Hash(
                prefix: "e66a2371-fecf-41de-9238-cb6c28a86cec:",
                property: .contact,
                algorithm: .farm,
                seed: 100,
                numberOfBuckets: 16384,
                overrides: nil
            ),
            bucket: AudienceHashSelector.Bucket(min: 11600, max: 13000),
            sticky: AudienceHashSelector.Sticky(
                id: "sticky ID",
                reportingMetadata: "sticky reporting",
                lastAccessTTL: 100.0
            )
        )


        var result = try await checker.evaluate(
            hashSelector: stickyHash,
            deviceInfoProvider: self.testDeviceInfo
        )

        #expect(
            AirshipDeviceAudienceResult(
                isMatch: true,
                reportingMetadata: [.string("sticky reporting")]
            ) ==
            result
        )

        var entry = await self.cache.entry(key: "StickyHash:match:some channel:sticky ID")!
        #expect(entry.ttl == 100.0)

        stickyHash.sticky = AudienceHashSelector.Sticky(
            id: "sticky ID",
            reportingMetadata: "updated sticky reporting",
            lastAccessTTL: 50.0
        )

        result = try await checker.evaluate(
            hashSelector: stickyHash,
            deviceInfoProvider: self.testDeviceInfo
        )

        #expect(
            AirshipDeviceAudienceResult(
                isMatch: true,
                reportingMetadata: [.string("sticky reporting")]
            ) ==
            result
        )

        entry = await self.cache.entry(key: "StickyHash:match:some channel:sticky ID")!
        #expect(entry.ttl == 50.0)

    }

    @Test
    func testStickyCacheMiss() async throws {
        self.testDeviceInfo.channelID = "some channel"
        self.testDeviceInfo.stableContactInfo = StableContactInfo(contactID: "not a match")

        let stickyHash = AudienceHashSelector(
            hash: AudienceHashSelector.Hash(
                prefix: "e66a2371-fecf-41de-9238-cb6c28a86cec:",
                property: .contact,
                algorithm: .farm,
                seed: 100,
                numberOfBuckets: 16384,
                overrides: nil
            ),
            bucket: AudienceHashSelector.Bucket(min: 11600, max: 13000),
            sticky: AudienceHashSelector.Sticky(
                id: "sticky ID",
                reportingMetadata: "sticky reporting",
                lastAccessTTL: 100.0
            )
        )

        let result = try await checker.evaluate(
            hashSelector: stickyHash,
            deviceInfoProvider: self.testDeviceInfo
        )

        #expect(
            AirshipDeviceAudienceResult(
                isMatch: false,
                reportingMetadata: [.string("sticky reporting")]
            ) ==
            result
        )

        let entry = await self.cache.entry(key: "StickyHash:not a match:some channel:sticky ID")!
        #expect(entry.ttl == 100.0)
        let decodedData = try JSONDecoder().decode(AirshipDeviceAudienceResult.self, from: entry.data)
        #expect(decodedData == result)
    }
}
