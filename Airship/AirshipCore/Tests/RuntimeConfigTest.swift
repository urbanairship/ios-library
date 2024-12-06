/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore

class RuntimeConfigTest: XCTestCase {
    func testUSSiteURLS() throws {
        let config = RuntimeConfig.testConfig(site: .us)
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
        let config = RuntimeConfig.testConfig(site: .eu)
        XCTAssertEqual("https://device-api.asnapieu.com", config.deviceAPIURL)
        XCTAssertEqual("https://combine.asnapieu.com", config.analyticsURL)
        XCTAssertEqual(
            "https://remote-data.asnapieu.com",
            config.remoteDataAPIURL
        )
    }

    func testInitialConfigURL() throws {
        let config = RuntimeConfig.testConfig(initialConfigURL: "cool://remote")
        XCTAssertEqual("cool://remote", config.remoteDataAPIURL)
    }

    func testRequireInitialRemoteConfigEnabled() throws {
        let config = RuntimeConfig.testConfig(
            requireInitialRemoteConfigEnabled: true
        )

        XCTAssertNil(config.deviceAPIURL)
        XCTAssertNil(config.analyticsURL)
        XCTAssertEqual(
            "https://remote-data.urbanairship.com",
            config.remoteDataAPIURL
        )
    }

    func testRemoteConfigOverride() async throws {
        let notificationCenter = NotificationCenter()

        let updatedCount = AirshipAtomicValue<Int>(0)
        notificationCenter.addObserver(
            forName: RuntimeConfig.configUpdatedEvent,
            object: nil,
            queue: nil
        ) { _ in
            updatedCount.value += 1
        }

        let config = RuntimeConfig.testConfig(notifiaconCenter: notificationCenter)

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
