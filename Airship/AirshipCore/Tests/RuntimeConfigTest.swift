/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore

class RuntimeConfigTest: XCTestCase {
    let dataStore = PreferenceDataStore(appKey: UUID().uuidString)
    let notificationCenter = NotificationCenter()
    let session: TestAirshipRequestSession = TestAirshipRequestSession()

    func testUSSiteURLS() throws {
        let appConfig = AirshipConfig()
        appConfig.site = .us
        appConfig.requireInitialRemoteConfigEnabled = false

        let config = RuntimeConfig(config: appConfig, dataStore: self.dataStore)
        XCTAssertEqual(
            "https://device-api.urbanairship.com",
            config.deviceAPIURL
        )
        XCTAssertEqual("https://combine.urbanairship.com", config.analyticsURL)
        XCTAssertEqual(
            "https://remote-data.urbanairship.com",
            config.remoteDataAPIURL
        )
    }

    func testEUSiteURLS() throws {
        let appConfig = AirshipConfig()
        appConfig.site = .eu
        appConfig.requireInitialRemoteConfigEnabled = false

        let config = RuntimeConfig(config: appConfig, dataStore: self.dataStore)
        XCTAssertEqual("https://device-api.asnapieu.com", config.deviceAPIURL)
        XCTAssertEqual("https://combine.asnapieu.com", config.analyticsURL)
        XCTAssertEqual(
            "https://remote-data.asnapieu.com",
            config.remoteDataAPIURL
        )
    }

    func testURLOverrides() throws {
        let appConfig = AirshipConfig()
        appConfig.deviceAPIURL = "cool://devices"
        appConfig.analyticsURL = "cool://analytics"
        appConfig.remoteDataAPIURL = "cool://remote"

        let config = RuntimeConfig(config: appConfig, dataStore: self.dataStore)
        XCTAssertEqual("cool://devices", config.deviceAPIURL)
        XCTAssertEqual("cool://analytics", config.analyticsURL)
        XCTAssertEqual("cool://remote", config.remoteDataAPIURL)
    }

    func testInitialConfigURL() throws {
        let appConfig = AirshipConfig()
        appConfig.initialConfigURL = "cool://remote"

        let config = RuntimeConfig(config: appConfig, dataStore: self.dataStore)
        XCTAssertEqual("cool://remote", config.remoteDataAPIURL)
    }

    func testInitialConfigURLOverridesRemoteDataAPIURL() throws {
        let appConfig = AirshipConfig()
        appConfig.initialConfigURL = "cool://remote-good"
        appConfig.remoteDataAPIURL = "cool://remote-bad"

        let config = RuntimeConfig(config: appConfig, dataStore: self.dataStore)
        XCTAssertEqual("cool://remote-good", config.remoteDataAPIURL)
    }

    func testRequireInitialRemoteConfigEnabled() throws {
        let appConfig = AirshipConfig()
        appConfig.requireInitialRemoteConfigEnabled = true

        let config = RuntimeConfig(config: appConfig, dataStore: self.dataStore)
        XCTAssertNil(config.deviceAPIURL)
        XCTAssertNil(config.analyticsURL)
        XCTAssertEqual(
            "https://remote-data.urbanairship.com",
            config.remoteDataAPIURL
        )
    }

    func testRemoteConfigOverride() async throws {
        let updatedCount = AirshipAtomicValue<Int>(0)
        self.notificationCenter.addObserver(
            forName: RuntimeConfig.configUpdatedEvent,
            object: nil,
            queue: nil
        ) { _ in
            updatedCount.value += 1
        }

        let config = RuntimeConfig(
            config: AirshipConfig(),
            dataStore: self.dataStore,
            requestSession: session,
            notificationCenter: self.notificationCenter
        )

        let airshipConfig = RemoteConfig.AirshipConfig(
            remoteDataURL: "cool://remote",
            deviceAPIURL: "cool://devices",
            analyticsURL: "cool://analytics",
            meteredUsageURL: "cool://meteredUsage"
        )

        await config.updateRemoteConfig(
            RemoteConfig(airshipConfig: airshipConfig)
        )

        XCTAssertEqual("cool://devices", config.deviceAPIURL)
        XCTAssertEqual("cool://analytics", config.analyticsURL)
        XCTAssertEqual("cool://remote", config.remoteDataAPIURL)
        XCTAssertEqual("cool://meteredUsage", config.meteredUsageURL)
        XCTAssertEqual(1, updatedCount.value)

        await config.updateRemoteConfig(
            RemoteConfig(airshipConfig: airshipConfig)
        )

        XCTAssertEqual("cool://devices", config.deviceAPIURL)
        XCTAssertEqual("cool://analytics", config.analyticsURL)
        XCTAssertEqual("cool://remote", config.remoteDataAPIURL)
        XCTAssertEqual("cool://meteredUsage", config.meteredUsageURL)
        XCTAssertEqual(1, updatedCount.value)

        let differentConfig = RemoteConfig.AirshipConfig(
            remoteDataURL: "neat://remote",
            deviceAPIURL: "neat://devices",
            analyticsURL: "neat://analytics",
            meteredUsageURL: "neat://meteredUsage"
        )

        await config.updateRemoteConfig(
            RemoteConfig(airshipConfig: differentConfig)
        )

        XCTAssertEqual("neat://devices", config.deviceAPIURL)
        XCTAssertEqual("neat://analytics", config.analyticsURL)
        XCTAssertEqual("neat://remote", config.remoteDataAPIURL)
        XCTAssertEqual("neat://meteredUsage", config.meteredUsageURL)
        XCTAssertEqual(2, updatedCount.value)
    }
}
