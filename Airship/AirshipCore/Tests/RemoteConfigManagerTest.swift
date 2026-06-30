import Testing
import Foundation

@testable import AirshipCore

@Suite(.timeLimit(.minutes(1)))
struct RemoteConfigManagerTest {

    private let dataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private let testRemoteData = TestRemoteData()
    private let notificationCenter = AirshipNotificationCenter.shared

    private let privacyManager: TestPrivacyManager
    private let remoteConfigManager: RemoteConfigManager
    private let config: RuntimeConfig = RuntimeConfig.testConfig()

    init() async throws {
        self.privacyManager = TestPrivacyManager(
            dataStore: self.dataStore,
            config: self.config,
            defaultEnabledFeatures: .all,
            notificationCenter: self.notificationCenter
        )

        self.remoteConfigManager = RemoteConfigManager(
            config: config,
            remoteData: self.testRemoteData,
            privacyManager: self.privacyManager,
            notificationCenter: self.notificationCenter,
            appVersion: "0.0.0"
        )
        self.remoteConfigManager.airshipReady()
    }

    @Test
    @MainActor
    func testEmptyConfig() async throws {
        self.config.updateRemoteConfig(
            RemoteConfig(
                airshipConfig: RemoteConfig.AirshipConfig(
                    remoteDataURL: "cool://remote",
                    deviceAPIURL: "cool://devices",
                    analyticsURL: "cool://analytics",
                    meteredUsageURL: "cool://meteredUsage"
                )
            )
        )

        let payload = RemoteDataPayload(
            type: "app_config",
            timestamp: Date(),
            data: AirshipJSON.null,
            remoteDataInfo: nil
        )

        let expectation = AirshipTestExpectation(description: "config updated")
        self.config.addRemoteConfigListener(notifyCurrent: false) { _, new in
            #expect(RemoteConfig() == new)
            expectation.fulfill()
        }

        self.testRemoteData.payloads = [payload]
        await fulfillment(of: [expectation], timeout: 10.0)
    }

    @Test
    @MainActor
    func testRemoteConfig() async throws {
        let remoteConfig = RemoteConfig(
            airshipConfig: RemoteConfig.AirshipConfig(
                remoteDataURL: "cool://remote",
                deviceAPIURL: "cool://devices",
                analyticsURL: "cool://analytics",
                meteredUsageURL: "cool://meteredUsage"
            ),
            meteredUsageConfig: RemoteConfig.MeteredUsageConfig(
                isEnabled: true,
                initialDelayMilliseconds: nil,
                intervalMilliseconds: nil
            )
        )

        let payload = RemoteDataPayload(
            type: "app_config",
            timestamp: Date(),
            data: try! AirshipJSON.wrap(remoteConfig),
            remoteDataInfo: nil
        )

        let expectation = AirshipTestExpectation(description: "config updated")
        self.config.addRemoteConfigListener(notifyCurrent: false) { _, new in
            #expect(remoteConfig == new)
            expectation.fulfill()
        }

        self.testRemoteData.payloads = [payload]
        await fulfillment(of: [expectation], timeout: 10.0)
    }

    @Test
    @MainActor
    func testCombienConfig() async throws {
        let iosConfig = RemoteConfig(
            airshipConfig: RemoteConfig.AirshipConfig(
                remoteDataURL: "ios://remote",
                deviceAPIURL: "ios://devices",
                analyticsURL: "ios://analytics",
                meteredUsageURL: "ios://meteredUsage"
            )
        )

        let commonConfig = RemoteConfig(
            airshipConfig: RemoteConfig.AirshipConfig(
                remoteDataURL: "common://remote",
                deviceAPIURL: "common://devices",
                analyticsURL: "common://analytics",
                meteredUsageURL: "common://meteredUsage"
            ),
            meteredUsageConfig: RemoteConfig.MeteredUsageConfig(
                isEnabled: true,
                initialDelayMilliseconds: nil,
                intervalMilliseconds: nil
            )
        )

        let expectedConfig = RemoteConfig(
            airshipConfig: iosConfig.airshipConfig,
            meteredUsageConfig: commonConfig.meteredUsageConfig
        )

        let platformPayload = RemoteDataPayload(
            type: "app_config:ios",
            timestamp: Date(),
            data: try! AirshipJSON.wrap(iosConfig),
            remoteDataInfo: nil
        )

        let commonPayload = RemoteDataPayload(
            type: "app_config",
            timestamp: Date(),
            data: try! AirshipJSON.wrap(commonConfig),
            remoteDataInfo: nil
        )

        let expectation = AirshipTestExpectation(description: "config updated")
        self.config.addRemoteConfigListener(notifyCurrent: false) { _, new in
            #expect(expectedConfig == new)
            expectation.fulfill()
        }

        self.testRemoteData.payloads = [commonPayload, platformPayload]
        await fulfillment(of: [expectation], timeout: 10.0)
    }
}
