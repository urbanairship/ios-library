import XCTest

@testable import AirshipCore

class RemoteConfigManagerTest: XCTestCase {

    private let dataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private let testRemoteData = TestRemoteData()
    private let testModuleAdapter = TestRemoteConfigModuleAdapter()
    private let notificationCenter = AirshipNotificationCenter.shared

    private var privacyManager: AirshipPrivacyManager!
    private var remoteConfigManager: RemoteConfigManager!
    private var config: RuntimeConfig!

    override func setUpWithError() throws {
        self.config = RuntimeConfig(
            config: AirshipConfig.config(),
            dataStore: dataStore
        )


        self.privacyManager = AirshipPrivacyManager(
            dataStore: self.dataStore,
            defaultEnabledFeatures: .all,
            notificationCenter: self.notificationCenter
        )

        self.remoteConfigManager = RemoteConfigManager(
            config: config,
            remoteData: self.testRemoteData,
            privacyManager: self.privacyManager,
            moduleAdapter: self.testModuleAdapter,
            notificationCenter: self.notificationCenter,
            appVersion: "0.0.0"
        )
        self.remoteConfigManager.airshipReady()
    }

    func testDisableModules() throws {
        let data = [
            "disable_features": [
                [
                    "modules": ["message_center", "channel"]
                ]
            ]
        ]

        let payload = RemoteDataPayload(
            type: "app_config",
            timestamp: Date(),
            data: try AirshipJSON.wrap(data),
            remoteDataInfo: nil
        )
        self.testRemoteData.payloads = [payload]

        let expectedDisabled: Set<RemoteConfigModule> = Set([
            RemoteConfigModule.messageCenter, RemoteConfigModule.channel,
        ])
        let expectedEnabled: Set<RemoteConfigModule> = Set(
            RemoteConfigModule.allCases
        )
        .subtracting(expectedDisabled)
        XCTAssertEqual(expectedDisabled, self.testModuleAdapter.disabledModules)
        XCTAssertEqual(expectedEnabled, self.testModuleAdapter.enabledModules)
    }

    func testFilterDisableInfos() throws {
        let data = [
            "disable_features": [
                [
                    "modules": ["in_app_v2"],
                    "sdk_versions": ["+"],
                    "remote_data_refresh_interval": 100.0,
                ],
                [
                    "modules": ["push"],
                    "sdk_versions": ["4.0.0"],
                ],
                [
                    "modules": ["message_center"],
                    "sdk_versions": [AirshipVersion.version],
                ] as [String : Any],
                [
                    "modules": ["contact"],
                    "app_versions": [
                        "value": ["version_matches": "[1.0, 8.0]"],
                        "scope": ["ios", "version"],
                    ] as [String : Any],
                    "remote_data_refresh_interval": 200.0,
                ],
                [
                    "modules": ["analytics"],
                    "sdk_versions": ["1.0.0", "[1.0,99.0["],
                ],
            ]
        ]

        let payload = RemoteDataPayload(
            type: "app_config",
            timestamp: Date(),
            data: try! AirshipJSON.wrap(data),
            remoteDataInfo: nil
        )

        self.testRemoteData.payloads = [payload]

        var expectedDisable: [RemoteConfigModule] = [
            .analytics, .messageCenter, .inAppAutomation,
        ]
        XCTAssertEqual(
            Set(expectedDisable),
            self.testModuleAdapter.disabledModules
        )
        XCTAssertEqual(
            100.0,
            self.testRemoteData.remoteDataRefreshInterval
        )

        self.remoteConfigManager = RemoteConfigManager(
            config: self.config,
            remoteData: self.testRemoteData,
            privacyManager: self.privacyManager,
            moduleAdapter: self.testModuleAdapter,
            notificationCenter: self.notificationCenter,
            appVersion: "2.0.0"
        )
        self.remoteConfigManager.airshipReady()

        self.testRemoteData.payloads = [payload]
        expectedDisable = [
            .analytics, .contact, .messageCenter, .inAppAutomation,
        ]
        XCTAssertEqual(
            Set(expectedDisable),
            self.testModuleAdapter.disabledModules
        )
        XCTAssertEqual(
            200.0,
            self.testRemoteData.remoteDataRefreshInterval
        )
    }

    func testRefreshInterval() throws {
        let data = [
            "disable_features": [
                [
                    "remote_data_refresh_interval": 100.0
                ]
            ]
        ]

        let payload = RemoteDataPayload(
            type: "app_config",
            timestamp: Date(),
            data: try! AirshipJSON.wrap(data),
            remoteDataInfo: nil
        )
        self.testRemoteData.payloads = [payload]
        XCTAssertEqual(
            100.0,
            self.testRemoteData.remoteDataRefreshInterval
        )
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

        XCTAssertEqual(
            Set(RemoteConfigModule.allCases),
            self.testModuleAdapter.enabledModules
        )

        XCTAssertEqual(
            10,
            self.testRemoteData.remoteDataRefreshInterval
        )

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
