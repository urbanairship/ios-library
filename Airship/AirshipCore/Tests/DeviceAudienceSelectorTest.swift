/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipCore

final class DefaultDeviceAudienceCheckerTest: XCTestCase, @unchecked Sendable {

    private let testDeviceInfo: TestAudienceDeviceInfoProvider = TestAudienceDeviceInfoProvider()
    private let audienceChecker = DefaultDeviceAudienceChecker(cache: TestCache())

    private let stickyHash = AudienceHashSelector(
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

    private let stickyHashInverse = AudienceHashSelector(
        hash: AudienceHashSelector.Hash(
            prefix: "e66a2371-fecf-41de-9238-cb6c28a86cec:",
            property: .contact,
            algorithm: .farm,
            seed: 100,
            numberOfBuckets: 16384,
            overrides: nil
        ),
        bucket: AudienceHashSelector.Bucket(min: 0, max: 11600),
        sticky: AudienceHashSelector.Sticky(
            id: "sticky ID",
            reportingMetadata: "inverse sticky reporting",
            lastAccessTTL: 100.0
        )
    )

    func testAirshipNotReadyThrows() async throws {
        testDeviceInfo.isAirshipReady = false
        do {
            _ = try await self.audienceChecker.evaluate(
                audienceSelector: .atomic(DeviceAudienceSelector()),
                newUserEvaluationDate: .now,
                deviceInfoProvider: self.testDeviceInfo
            )
            XCTFail("Should throw")
        } catch {}
    }

    func testEmptyAudience() async throws {
        try await self.assert(
            audienceSelector: DeviceAudienceSelector(),
            isMatch: true
        )
    }

    func testNewUserCondition() async throws {
        let now = Date()
        testDeviceInfo.installDate = now
        let audience = DeviceAudienceSelector(newUser: true)

        try await self.assert(
            audienceSelector: audience,
            newUserEvaluationDate: now,
            isMatch: true
        )

        try await self.assert(
            audienceSelector: audience,
            newUserEvaluationDate: now.advanced(by: -1.0),
            isMatch: true
        )

        try await self.assert(
            audienceSelector: audience,
            newUserEvaluationDate: now.advanced(by: 1.0),
            isMatch: false
        )
    }

    func testNotifiicationOptIn() async throws {
        self.testDeviceInfo.isUserOptedInPushNotifications = false
        let audience = DeviceAudienceSelector(notificationOptIn: true)

        try await self.assert(
            audienceSelector: audience,
            isMatch: false
        )


        self.testDeviceInfo.isUserOptedInPushNotifications = true
        try await self.assert(
            audienceSelector: audience,
            isMatch: true
        )
    }

    func testNotifiicationOptOut() async throws {
        self.testDeviceInfo.isUserOptedInPushNotifications = true

        let audience = DeviceAudienceSelector(notificationOptIn: false)
        try await self.assert(
            audienceSelector: audience,
            isMatch: false
        )

        self.testDeviceInfo.isUserOptedInPushNotifications = false
        try await self.assert(
            audienceSelector: audience,
            isMatch: true
        )
    }

    func testRequireAnalyticsTrue() async throws {
        self.testDeviceInfo.analyticsEnabled = true

        let audience = DeviceAudienceSelector(requiresAnalytics: true)
        try await self.assert(
            audienceSelector: audience,
            isMatch: true
        )

        self.testDeviceInfo.analyticsEnabled = false
        try await self.assert(
            audienceSelector: audience,
            isMatch: false
        )
    }

    func testRequireAnalyticsFalse() async throws {
        self.testDeviceInfo.analyticsEnabled = true

        let audience = DeviceAudienceSelector(requiresAnalytics: false)
        try await self.assert(
            audienceSelector: audience,
            isMatch: true
        )

        self.testDeviceInfo.analyticsEnabled = false
        try await self.assert(
            audienceSelector: audience,
            isMatch: true
        )
    }

    func testLocale() async throws {
        self.testDeviceInfo.locale = Locale(identifier: "de")
        let audience = DeviceAudienceSelector(
            languageIDs: [ "fr", "en-CA"]
        )
        
        try await self.assert(
            audienceSelector: audience,
            isMatch: false
        )

        self.testDeviceInfo.locale = Locale(identifier: "en-GB")
        try await self.assert(
            audienceSelector: audience,
            isMatch: false
        )

        self.testDeviceInfo.locale = Locale(identifier: "en")
        try await self.assert(
            audienceSelector: audience,
            isMatch: false
        )

        self.testDeviceInfo.locale = Locale(identifier: "fr-FR")
        try await self.assert(
            audienceSelector: audience,
            isMatch: true
        )

        self.testDeviceInfo.locale = Locale(identifier: "en-CA")
        try await self.assert(
            audienceSelector: audience,
            isMatch: true
        )

        self.testDeviceInfo.locale = Locale(identifier: "en-CA-POSIX")
        try await self.assert(
            audienceSelector: audience,
            isMatch: true
        )
    }

    func testTags() async throws {
        let audience = DeviceAudienceSelector(
            tagSelector: .and([.tag("bar"), .tag("foo")])
        )

        try await self.assert(
            audienceSelector: audience,
            isMatch: false
        )

        self.testDeviceInfo.tags = Set(["foo"])
        try await self.assert(
            audienceSelector: audience,
            isMatch: false
        )

        self.testDeviceInfo.tags = Set(["foo", "bar"])
        try await self.assert(
            audienceSelector: audience,
            isMatch: true
        )
    }

    func testTestDevices() async throws {
        let audience = DeviceAudienceSelector(
            testDevices: ["obIvSbh47TjjqfCrPatbXQ==\n"] // test channel
        )

        try await self.assert(
            audienceSelector: audience,
            isMatch: false
        )

        self.testDeviceInfo.channelID = "wrong channnel"
        try await self.assert(
            audienceSelector: audience,
            isMatch: false
        )

        self.testDeviceInfo.channelID = "test channel"
        try await self.assert(
            audienceSelector: audience,
            isMatch: true
        )
    }

    func testVersion() async throws {
        let audience = DeviceAudienceSelector(
            versionPredicate: JSONPredicate(
                jsonMatcher: JSONMatcher(
                    valueMatcher: JSONValueMatcher.matcherWhereStringEquals("1.1.1"),
                    scope: ["ios", "version"]
                )
            )
        )

        try await self.assert(
            audienceSelector: audience,
            isMatch: false
        )

        self.testDeviceInfo.appVersion = "1.0.0"
        try await self.assert(
            audienceSelector: audience,
            isMatch: false
        )

        self.testDeviceInfo.appVersion = "1.1.1"
        try await self.assert(
            audienceSelector: audience,
            isMatch: true
        )
    }

    func testPermissions() async throws {
        let audience = DeviceAudienceSelector(
            permissionPredicate: JSONPredicate(
                jsonMatcher: JSONMatcher(
                    valueMatcher: JSONValueMatcher.matcherWhereStringEquals("granted"),
                    scope: ["display_notifications"]
                )
            )
        )

        try await self.assert(
            audienceSelector: audience,
            isMatch: false
        )

        self.testDeviceInfo.permissions = [.displayNotifications: .denied]
        try await self.assert(
            audienceSelector: audience,
            isMatch: false
        )

        self.testDeviceInfo.permissions = [.displayNotifications: .granted]
        try await self.assert(
            audienceSelector: audience,
            isMatch: true
        )
    }

    func testLocationOptIn() async throws {
        let audience = DeviceAudienceSelector(
            locationOptIn: true
        )

        try await self.assert(
            audienceSelector: audience,
            isMatch: false
        )

        self.testDeviceInfo.permissions = [.location: .denied]
        try await self.assert(
            audienceSelector: audience,
            isMatch: false
        )

        self.testDeviceInfo.permissions = [.location: .granted]
        try await self.assert(
            audienceSelector: audience,
            isMatch: true
        )
    }

    func testLocationOptOut() async throws {
        let audience = DeviceAudienceSelector(
            locationOptIn: false
        )

        try await self.assert(
            audienceSelector: audience,
            isMatch: true
        )

        self.testDeviceInfo.permissions = [.location: .denied]
        try await self.assert(
            audienceSelector: audience,
            isMatch: true
        )

        self.testDeviceInfo.permissions = [.location: .granted]
        try await self.assert(
            audienceSelector: audience,
            isMatch: false
        )
    }

    func testContactHash() async throws {
        let hash = AudienceHashSelector(
            hash: AudienceHashSelector.Hash(
                prefix: "e66a2371-fecf-41de-9238-cb6c28a86cec:",
                property: .contact,
                algorithm: .farm,
                seed: 100,
                numberOfBuckets: 16384,
                overrides: nil
            ),
            bucket: AudienceHashSelector.Bucket(min: 11600, max: 13000)
        )

        let audience = DeviceAudienceSelector(
            hashSelector: hash
        )

        self.testDeviceInfo.channelID = "not a match"

        self.testDeviceInfo.stableContactInfo = StableContactInfo(contactID: "not a match")
        try await self.assert(
            audienceSelector: audience,
            isMatch: false
        )

        self.testDeviceInfo.stableContactInfo = StableContactInfo(contactID: "match")
        try await self.assert(
            audienceSelector: audience,
            isMatch: true
        )
    }

    func testChannelHash() async throws {
        let hash = AudienceHashSelector(
            hash: AudienceHashSelector.Hash(
                prefix: "e66a2371-fecf-41de-9238-cb6c28a86cec:",
                property: .channel,
                algorithm: .farm,
                seed: 100,
                numberOfBuckets: 16384,
                overrides: nil
            ),
            bucket: AudienceHashSelector.Bucket(min: 11600, max: 13000)
        )

        let audience = DeviceAudienceSelector(
            hashSelector: hash
        )

        self.testDeviceInfo.channelID = "not a match"
        self.testDeviceInfo.stableContactInfo = StableContactInfo(contactID: "not a match")
        try await self.assert(
            audienceSelector: audience,
            isMatch: false
        )

        self.testDeviceInfo.channelID = "match"
        try await self.assert(
            audienceSelector: audience,
            isMatch: true
        )
    }

    func testDeviceTypes() async throws {
        let audience = DeviceAudienceSelector(
            deviceTypes: ["android", "ios"]
        )

        try await self.assert(
            audienceSelector: audience,
            isMatch: true
        )
    }

    func testDeviceTypesNoIOS() async throws {
        let audience = DeviceAudienceSelector(
            deviceTypes: ["android", "web"]
        )

        try await self.assert(
            audienceSelector: audience,
            isMatch: false
        )
    }

    func testEmtpyDeviceTypes() async throws {
        let audience = DeviceAudienceSelector(
            deviceTypes: []
        )

        try await self.assert(
            audienceSelector: audience,
            isMatch: false
        )
    }

    func testStickyHash() async throws {
        self.testDeviceInfo.channelID = UUID().uuidString

        let audience = DeviceAudienceSelector(
            hashSelector: stickyHash
        )

        self.testDeviceInfo.stableContactInfo = StableContactInfo(contactID: "not a match")

        try await self.assert(
            audienceSelector: audience,
            isMatch: false,
            reportingMetadata: [stickyHash.sticky!.reportingMetadata!]
        )

        self.testDeviceInfo.stableContactInfo = StableContactInfo(contactID: "match")
        try await self.assert(
            audienceSelector: audience,
            isMatch: true,
            reportingMetadata: [stickyHash.sticky!.reportingMetadata!]
        )

        // Update sticky hash to swap matches
        let updatedAudience = DeviceAudienceSelector(
            hashSelector: stickyHashInverse
        )

        // Should be the same results
        self.testDeviceInfo.stableContactInfo = StableContactInfo(contactID: "not a match")
        try await self.assert(
            audienceSelector: updatedAudience,
            isMatch: false,
            reportingMetadata: [stickyHash.sticky!.reportingMetadata!]
        )

        self.testDeviceInfo.stableContactInfo = StableContactInfo(contactID: "match")
        try await self.assert(
            audienceSelector: updatedAudience,
            isMatch: true,
            reportingMetadata: [stickyHash.sticky!.reportingMetadata!]
        )

        // New contacts should reevaluate
        self.testDeviceInfo.stableContactInfo = StableContactInfo(contactID: "also is a match")
        try await self.assert(
            audienceSelector: updatedAudience,
            isMatch: true,
            reportingMetadata: [stickyHashInverse.sticky!.reportingMetadata!]
        )
    }

    func testORMatch() async throws {
        self.testDeviceInfo.analyticsEnabled = false
        let audience = CompoundDeviceAudienceSelector.or(
            [
                .atomic(DeviceAudienceSelector(requiresAnalytics: false)),
                .atomic(DeviceAudienceSelector(requiresAnalytics: true)),
            ]
        )

        try await self.assert(
            compoundSelector: audience,
            isMatch: true
        )
    }

    func testORMatchFirstNoMatch() async throws {
        self.testDeviceInfo.analyticsEnabled = false
        let audience = CompoundDeviceAudienceSelector.or(
            [
                .atomic(DeviceAudienceSelector(requiresAnalytics: true)),
                .atomic(DeviceAudienceSelector(requiresAnalytics: false)),
            ]
        )

        try await self.assert(
            compoundSelector: audience,
            isMatch: true
        )
    }

    func testORMiss() async throws {
        self.testDeviceInfo.analyticsEnabled = false
        self.testDeviceInfo.isUserOptedInPushNotifications = false

        let audience = CompoundDeviceAudienceSelector.or(
            [
                .atomic(DeviceAudienceSelector(requiresAnalytics: true)),
                .atomic(DeviceAudienceSelector(notificationOptIn: true)),
            ]
        )

        try await self.assert(
            compoundSelector: audience,
            isMatch: false
        )
    }


    func testEmptyOR() async throws {
        let audience = CompoundDeviceAudienceSelector.or([])
        try await self.assert(
            compoundSelector: audience,
            isMatch: false
        )
    }

    func testANDMatch() async throws {
        self.testDeviceInfo.analyticsEnabled = true
        self.testDeviceInfo.isUserOptedInPushNotifications = true

        let audience = CompoundDeviceAudienceSelector.or(
            [
                .atomic(DeviceAudienceSelector(requiresAnalytics: true)),
                .atomic(DeviceAudienceSelector(notificationOptIn: true)),
            ]
        )

        try await self.assert(
            compoundSelector: audience,
            isMatch: true
        )
    }

    func testANDMiss() async throws {
        self.testDeviceInfo.analyticsEnabled = false
        self.testDeviceInfo.isUserOptedInPushNotifications = true

        let audience = CompoundDeviceAudienceSelector.and(
            [
                .atomic(DeviceAudienceSelector(requiresAnalytics: true)),
                .atomic(DeviceAudienceSelector(notificationOptIn: true)),
            ]
        )

        try await self.assert(
            compoundSelector: audience,
            isMatch: false
        )
    }

    func testEmptyAND() async throws {
        let audience = CompoundDeviceAudienceSelector.and([])
        try await self.assert(
            compoundSelector: audience,
            isMatch: true
        )
    }

    func testNOT() async throws {
        self.testDeviceInfo.analyticsEnabled = false
        self.testDeviceInfo.isUserOptedInPushNotifications = true

        let audience = CompoundDeviceAudienceSelector.not(
            .and(
                [
                    .atomic(DeviceAudienceSelector(requiresAnalytics: true)),
                    .atomic(DeviceAudienceSelector(notificationOptIn: true)),
                ]
            )
        )

        try await self.assert(
            compoundSelector: audience,
            isMatch: true
        )
    }

    func testStickyHashShortCircuitOR() async throws {
        var stickyHashDiffID = stickyHash
        stickyHashDiffID.sticky = AudienceHashSelector.Sticky(
            id: UUID().uuidString,
            reportingMetadata: .string(UUID().uuidString),
            lastAccessTTL: 100.0
        )

        self.testDeviceInfo.channelID = UUID().uuidString
        self.testDeviceInfo.stableContactInfo = StableContactInfo(contactID: "match")

        // short circuits, only get the first one
        try await self.assert(
            compoundSelector: .or(
                [
                    .atomic(DeviceAudienceSelector(hashSelector: stickyHash)),
                    .atomic(DeviceAudienceSelector(hashSelector: stickyHashDiffID)),
                ]
            ),
            isMatch: true,
            reportingMetadata: [stickyHash.sticky!.reportingMetadata!]
        )
    }

    func testStickyHashShortCircuitAND() async throws {
        var stickyHashDiffID = stickyHash
        stickyHashDiffID.sticky = AudienceHashSelector.Sticky(
            id: UUID().uuidString,
            reportingMetadata: .string(UUID().uuidString),
            lastAccessTTL: 100.0
        )

        self.testDeviceInfo.channelID = UUID().uuidString
        self.testDeviceInfo.stableContactInfo = StableContactInfo(contactID: "match")

        // short circuits, only get the first one
        try await self.assert(
            compoundSelector: .and(
                [
                    .atomic(DeviceAudienceSelector(hashSelector: stickyHashInverse)),
                    .atomic(DeviceAudienceSelector(hashSelector: stickyHashDiffID)),
                ]
            ),
            isMatch: false,
            reportingMetadata: [stickyHashInverse.sticky!.reportingMetadata!]
        )
    }

    func testStickyHashMultiple() async throws {
        var stickyHashDiffID = stickyHash
        stickyHashDiffID.sticky = AudienceHashSelector.Sticky(
            id: UUID().uuidString,
            reportingMetadata: .string(UUID().uuidString),
            lastAccessTTL: 100.0
        )

        self.testDeviceInfo.channelID = UUID().uuidString
        self.testDeviceInfo.stableContactInfo = StableContactInfo(contactID: "match")

        // short circuits, only get the first one
        try await self.assert(
            compoundSelector: .and(
                [
                    .atomic(DeviceAudienceSelector(hashSelector: stickyHash)),
                    .atomic(DeviceAudienceSelector(hashSelector: stickyHashDiffID)),
                ]
            ),
            isMatch: true,
            reportingMetadata: [
                stickyHash.sticky!.reportingMetadata!,
                stickyHashDiffID.sticky!.reportingMetadata!
            ]
        )
    }

    func assert(
        audienceSelector: DeviceAudienceSelector,
        newUserEvaluationDate: Date = Date.distantPast,
        isMatch: Bool,
        reportingMetadata: [AirshipJSON]? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        try await self.assert(
            compoundSelector: .atomic(audienceSelector),
            newUserEvaluationDate: newUserEvaluationDate,
            isMatch: isMatch,
            reportingMetadata: reportingMetadata,
            file: file,
            line: line
        )
    }

    func assert(
        compoundSelector: CompoundDeviceAudienceSelector,
        newUserEvaluationDate: Date = Date.distantPast,
        isMatch: Bool,
        reportingMetadata: [AirshipJSON]? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let result = try await self.audienceChecker.evaluate(
            audienceSelector: compoundSelector,
            newUserEvaluationDate: newUserEvaluationDate,
            deviceInfoProvider: self.testDeviceInfo
        )

        XCTAssertEqual(result.isMatch, isMatch, file: file, line: line)
        XCTAssertEqual(result.reportingMetadata, reportingMetadata, file: file, line: line)
    }
}



