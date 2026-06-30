/* Copyright Airship and Contributors */

import Testing

@testable import AirshipCore
import Foundation

@Suite struct RuntimeConfigTest {
    @Test
    func testUSSiteURLS() throws {
        let config = RuntimeConfig.testConfig(site: .us)
        #expect(
            "https://device-api.urbanairship.com" ==
            config.deviceAPIURL
        )
        #expect("https://combine.urbanairship.com" == config.analyticsURL)
        #expect(
            "https://remote-data.urbanairship.com" ==
            config.remoteDataAPIURL
        )
    }

    @Test
    func testEUSiteURLS() throws {
        let config = RuntimeConfig.testConfig(site: .eu)
        #expect("https://device-api.asnapieu.com" == config.deviceAPIURL)
        #expect("https://combine.asnapieu.com" == config.analyticsURL)
        #expect(
            "https://remote-data.asnapieu.com" ==
            config.remoteDataAPIURL
        )
    }

    @Test
    func testInitialConfigURL() throws {
        let config = RuntimeConfig.testConfig(initialConfigURL: "cool://remote")
        #expect("cool://remote" == config.remoteDataAPIURL)
    }

    @Test
    func testRequireInitialRemoteConfigEnabled() throws {
        let config = RuntimeConfig.testConfig(
            requireInitialRemoteConfigEnabled: true
        )

        #expect(config.deviceAPIURL == nil)
        #expect(config.analyticsURL == nil)
        #expect(
            "https://remote-data.urbanairship.com" ==
            config.remoteDataAPIURL
        )
    }

    @Test
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

        #expect("cool://devices" == config.deviceAPIURL)
        #expect("cool://analytics" == config.analyticsURL)
        #expect("cool://remote" == config.remoteDataAPIURL)
        #expect("cool://meteredUsage" == config.meteredUsageURL)
        #expect(1 == updatedCount.value)

        await config.updateRemoteConfig(
            RemoteConfig(airshipConfig: airshipConfig)
        )

        #expect("cool://devices" == config.deviceAPIURL)
        #expect("cool://analytics" == config.analyticsURL)
        #expect("cool://remote" == config.remoteDataAPIURL)
        #expect("cool://meteredUsage" == config.meteredUsageURL)
        #expect(1 == updatedCount.value)

        let differentConfig = RemoteConfig.AirshipConfig(
            remoteDataURL: "neat://remote",
            deviceAPIURL: "neat://devices",
            analyticsURL: "neat://analytics",
            meteredUsageURL: "neat://meteredUsage"
        )

        await config.updateRemoteConfig(
            RemoteConfig(airshipConfig: differentConfig)
        )

        #expect("neat://devices" == config.deviceAPIURL)
        #expect("neat://analytics" == config.analyticsURL)
        #expect("neat://remote" == config.remoteDataAPIURL)
        #expect("neat://meteredUsage" == config.meteredUsageURL)
        #expect(2 == updatedCount.value)
    }
}
