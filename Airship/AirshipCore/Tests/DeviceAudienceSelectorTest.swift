/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipCore

final class DeviceAudienceSelectorTest: XCTestCase, @unchecked Sendable {

    private let testDeviceInfo: TestAudienceDeviceInfoProvider = TestAudienceDeviceInfoProvider()
    
    func testAirshipNotReadyThrows() async throws {
        testDeviceInfo.isAirshipReady = false
        let audience = DeviceAudienceSelector()
        do {
            _ = try await audience.evaluate(deviceInfoProvider: self.testDeviceInfo)
            XCTFail("Should throw")
        } catch {}
    }

    func testEmptyAudience() async throws {
        let audience = DeviceAudienceSelector()
        try await assertTrue {
            try await audience.evaluate(deviceInfoProvider: self.testDeviceInfo)
        }
    }

    func testNewUserCondition() async throws {
        let now = Date()
        testDeviceInfo.installDate = now
        let audience = DeviceAudienceSelector(newUser: true)

        try await assertTrue {
            try await audience.evaluate(
                newUserEvaluationDate: now,
                deviceInfoProvider: self.testDeviceInfo
            )
        }

        try await assertTrue {
            try await audience.evaluate(
                newUserEvaluationDate: now.addingTimeInterval(-1.0),
                deviceInfoProvider: self.testDeviceInfo
            )
        }

        try await assertFalse {
            try await audience.evaluate(
                newUserEvaluationDate: now.addingTimeInterval(1.0),
                deviceInfoProvider: self.testDeviceInfo
            )
        }
    }

    func testNotifiicationOptIn() async throws {
        self.testDeviceInfo.isUserOptedInPushNotifications = false

        let audience = DeviceAudienceSelector(notificationOptIn: true)
        try await assertFalse {
            try await audience.evaluate(deviceInfoProvider: self.testDeviceInfo)
        }

        self.testDeviceInfo.isUserOptedInPushNotifications = true
        try await assertTrue {
            try await audience.evaluate(deviceInfoProvider: self.testDeviceInfo)
        }
    }

    func testNotifiicationOptOut() async throws {
        self.testDeviceInfo.isUserOptedInPushNotifications = true

        let audience = DeviceAudienceSelector(notificationOptIn: false)
        try await assertFalse {
            try await audience.evaluate(deviceInfoProvider: self.testDeviceInfo)
        }

        self.testDeviceInfo.isUserOptedInPushNotifications = false
        try await assertTrue {
            try await audience.evaluate(deviceInfoProvider: self.testDeviceInfo)
        }
    }

    func testRequireAnalyticsTrue() async throws {
        self.testDeviceInfo.analyticsEnabled = true

        let audience = DeviceAudienceSelector(requiresAnalytics: true)
        try await assertTrue {
            try await audience.evaluate(deviceInfoProvider: self.testDeviceInfo)
        }

        self.testDeviceInfo.analyticsEnabled = false
        try await assertFalse {
            try await audience.evaluate(deviceInfoProvider: self.testDeviceInfo)
        }
    }

    func testRequireAnalyticsFalse() async throws {
        self.testDeviceInfo.analyticsEnabled = true

        let audience = DeviceAudienceSelector(requiresAnalytics: false)
        try await assertTrue {
            try await audience.evaluate(deviceInfoProvider: self.testDeviceInfo)
        }

        self.testDeviceInfo.analyticsEnabled = false
        try await assertTrue {
            try await audience.evaluate(deviceInfoProvider: self.testDeviceInfo)
        }
    }

    func testLocale() async throws {
        self.testDeviceInfo.locale = Locale(identifier: "de")
        let audience = DeviceAudienceSelector(
            languageIDs: [ "fr", "en-CA"]
        )
        
        try await assertFalse {
            try await audience.evaluate(deviceInfoProvider: self.testDeviceInfo)
        }

        self.testDeviceInfo.locale = Locale(identifier: "en-GB")
        try await assertFalse {
            try await audience.evaluate(deviceInfoProvider: self.testDeviceInfo)
        }

        self.testDeviceInfo.locale = Locale(identifier: "en")
        try await assertFalse {
            try await audience.evaluate(deviceInfoProvider: self.testDeviceInfo)
        }

        self.testDeviceInfo.locale = Locale(identifier: "fr-FR")
        try await assertTrue {
            try await audience.evaluate(deviceInfoProvider: self.testDeviceInfo)
        }

        self.testDeviceInfo.locale = Locale(identifier: "en-CA")
        try await assertTrue {
            try await audience.evaluate(deviceInfoProvider: self.testDeviceInfo)
        }

        self.testDeviceInfo.locale = Locale(identifier: "en-CA-POSIX")
        try await assertTrue {
            try await audience.evaluate(deviceInfoProvider: self.testDeviceInfo)
        }
    }

    func testTags() async throws {
        let audience = DeviceAudienceSelector(
            tagSelector: .and([.tag("bar"), .tag("foo")])
        )

        try await assertFalse {
            try await audience.evaluate(deviceInfoProvider: self.testDeviceInfo)
        }

        self.testDeviceInfo.tags = Set(["foo"])
        try await assertFalse {
            try await audience.evaluate(deviceInfoProvider: self.testDeviceInfo)
        }

        self.testDeviceInfo.tags = Set(["foo", "bar"])
        try await assertTrue {
            try await audience.evaluate(deviceInfoProvider: self.testDeviceInfo)
        }
    }

    func testTestDevices() async throws {
        let audience = DeviceAudienceSelector(
            testDevices: ["obIvSbh47TjjqfCrPatbXQ==\n"] // test channel
        )

        try await assertFalse {
            try await audience.evaluate(deviceInfoProvider: self.testDeviceInfo)
        }

        self.testDeviceInfo.channelID = "wrong channnel"
        try await assertFalse {
            try await audience.evaluate(deviceInfoProvider: self.testDeviceInfo)
        }

        self.testDeviceInfo.channelID = "test channel"
        try await assertTrue {
            try await audience.evaluate(deviceInfoProvider: self.testDeviceInfo)
        }
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

        try await assertFalse {
            try await audience.evaluate(deviceInfoProvider: self.testDeviceInfo)
        }
        
        self.testDeviceInfo.appVersion = "1.0.0"
        try await assertFalse {
            try await audience.evaluate(deviceInfoProvider: self.testDeviceInfo)
        }

        self.testDeviceInfo.appVersion = "1.1.1"
        try await assertTrue {
            try await audience.evaluate(deviceInfoProvider: self.testDeviceInfo)
        }
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

        try await assertFalse {
            try await audience.evaluate(deviceInfoProvider: self.testDeviceInfo)
        }

        self.testDeviceInfo.permissions = [.displayNotifications: .denied]
        try await assertFalse {
            try await audience.evaluate(deviceInfoProvider: self.testDeviceInfo)
        }

        self.testDeviceInfo.permissions = [.displayNotifications: .granted]
        try await assertTrue {
            try await audience.evaluate(deviceInfoProvider: self.testDeviceInfo)
        }
    }

    func testLocationOptIn() async throws {
        let audience = DeviceAudienceSelector(
            locationOptIn: true
        )

        try await assertFalse {
            try await audience.evaluate(deviceInfoProvider: self.testDeviceInfo)
        }

        self.testDeviceInfo.permissions = [.location: .denied]
        try await assertFalse {
            try await audience.evaluate(deviceInfoProvider: self.testDeviceInfo)
        }

        self.testDeviceInfo.permissions = [.location: .granted]
        try await assertTrue {
            try await audience.evaluate(deviceInfoProvider: self.testDeviceInfo)
        }
    }

    func testLocationOptOut() async throws {
        let audience = DeviceAudienceSelector(
            locationOptIn: false
        )

        try await assertTrue {
            try await audience.evaluate(deviceInfoProvider: self.testDeviceInfo)
        }

        self.testDeviceInfo.permissions = [.location: .denied]
        try await assertTrue {
            try await audience.evaluate(deviceInfoProvider: self.testDeviceInfo)
        }

        self.testDeviceInfo.permissions = [.location: .granted]
        try await assertFalse {
            try await audience.evaluate(deviceInfoProvider: self.testDeviceInfo)
        }
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
            bucket: AudienceHashSelector.Bucket(min: 4647, max: 11280)
        )

        let audience = DeviceAudienceSelector(
            hashSelector: hash
        )

        self.testDeviceInfo.channelID = "not a match"

        self.testDeviceInfo.stableContactID = "not a match"
        try await assertFalse {
            try await audience.evaluate(deviceInfoProvider: self.testDeviceInfo)
        }

        self.testDeviceInfo.stableContactID = "match"
        try await assertTrue {
            try await audience.evaluate(deviceInfoProvider: self.testDeviceInfo)
        }
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
            bucket: AudienceHashSelector.Bucket(min: 4647, max: 11280)
        )

        let audience = DeviceAudienceSelector(
            hashSelector: hash
        )

        self.testDeviceInfo.channelID = "not a match"
        self.testDeviceInfo.stableContactID = "not a match"
        try await assertFalse {
            try await audience.evaluate(deviceInfoProvider: self.testDeviceInfo)
        }

        self.testDeviceInfo.channelID = "match"
        try await assertTrue {
            try await audience.evaluate(deviceInfoProvider: self.testDeviceInfo)
        }
    }

    func assertTrue(
        block: @Sendable () async throws -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let result = try await block()
        XCTAssertTrue(result, file: file, line: line)
    }

    func assertFalse(
        block: @Sendable () async throws -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let result = try await block()
        XCTAssertFalse(result, file: file, line: line)
    }


}


class TestAudienceDeviceInfoProvider: AudienceDeviceInfoProvider {
    var isAirshipReady: Bool = true

    var tags: Set<String> = Set()

    var channelID: String? = nil

    var locale: Locale = Locale.current

    var appVersion: String? = nil

    var permissions: [AirshipPermission : AirshipPermissionStatus] = [:]

    var isUserOptedInPushNotifications: Bool = false

    var analyticsEnabled: Bool = false

    var installDate: Date = Date()

    var stableContactID: String = "stable"
}
