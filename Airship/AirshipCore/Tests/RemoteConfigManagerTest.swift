import XCTest

@testable import AirshipCore

class RemoteConfigManagerTest: XCTestCase {

    private let dataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private let testRemoteData = TestRemoteData()
    private let notificationCenter = AirshipNotificationCenter.shared

    private var privacyManager: AirshipPrivacyManager!
    private var remoteConfigManager: RemoteConfigManager!
    private var config: RuntimeConfig!

    override func setUp() async throws {
        self.config = RuntimeConfig(
            config: AirshipConfig.config(),
            dataStore: dataStore
        )

        self.privacyManager = await AirshipPrivacyManager(
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

    @MainActor
    func testEmptyConfig() throws {
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

        let expectation = expectation(description: "config updated")
        self.config.addRemoteConfigListener(notifyCurrent: false) { _, new in
            XCTAssertEqual(RemoteConfig(), new)
            expectation.fulfill()
        }

        self.testRemoteData.payloads = [payload]
        wait(for: [expectation], timeout: 10.0)
    }

    @MainActor
    func testRemoteConfig() throws {
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

        let expectation = expectation(description: "config updated")
        self.config.addRemoteConfigListener(notifyCurrent: false) { _, new in
            XCTAssertEqual(remoteConfig, new)
            expectation.fulfill()
        }

        self.testRemoteData.payloads = [payload]
        wait(for: [expectation], timeout: 10.0)
    }

    @MainActor
    func testCombienConfig() throws {
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

        let expectation = expectation(description: "config updated")
        self.config.addRemoteConfigListener(notifyCurrent: false) { _, new in
            XCTAssertEqual(expectedConfig, new)
            expectation.fulfill()
        }

        self.testRemoteData.payloads = [commonPayload, platformPayload]
        wait(for: [expectation], timeout: 10.0)
    }
}
