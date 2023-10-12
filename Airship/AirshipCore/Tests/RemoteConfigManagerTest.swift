import XCTest

@testable import AirshipCore

class RemoteConfigManagerTest: XCTestCase {

    let dataStore = PreferenceDataStore(appKey: UUID().uuidString)
    let testRemoteData = TestRemoteData()
    let testModuleAdapter = TestRemoteConfigModuleAdapter()
    let notificationCenter = AirshipNotificationCenter.shared

    var privacyManager: AirshipPrivacyManager!
    var remoteConfigManager: RemoteConfigManager!


    override func setUpWithError() throws {
        self.privacyManager = AirshipPrivacyManager(
            dataStore: self.dataStore,
            defaultEnabledFeatures: .all,
            notificationCenter: self.notificationCenter
        )

        self.remoteConfigManager = RemoteConfigManager(
            remoteData: self.testRemoteData,
            privacyManager: self.privacyManager,
            meteredUsage: AirshipMeteredUsage.test(dataStore: dataStore, privacyManager: privacyManager),
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

    func testEmptyConfig() throws {
        let payload = RemoteDataPayload(
            type: "app_config",
            timestamp: Date(),
            data: AirshipJSON.null,
            remoteDataInfo: nil
        )
        self.testRemoteData.payloads = [payload]

        XCTAssertEqual(
            Set(RemoteConfigModule.allCases),
            self.testModuleAdapter.enabledModules
        )
        RemoteConfigModule.allCases.forEach { module in
            XCTAssertTrue(
                self.testModuleAdapter.moduleConfig.keys.contains(where: {
                    $0 == module
                })
            )
            XCTAssertNil(self.testModuleAdapter.moduleConfig[module]!)
        }
        XCTAssertEqual(
            10,
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

    func testModuleConfig() throws {
        let data: [String: Any] = [
            "contact": "some-config",
            "channel": ["neat"],
        ]

        let payload = RemoteDataPayload(
            type: "app_config:ios",
            timestamp: Date(),
            data: try! AirshipJSON.wrap(data),
            remoteDataInfo: nil
        )
        self.testRemoteData.payloads = [payload]

        XCTAssertEqual(
            "some-config",
            self.testModuleAdapter.moduleConfig[.contact] as! String
        )
        XCTAssertEqual(
            ["neat"],
            self.testModuleAdapter.moduleConfig[.channel] as! [String]
        )
    }

    func testRemoteConfig() throws {
        let remoteConfig = RemoteConfig(
            remoteDataURL: "cool://remote",
            deviceAPIURL: "cool://devices",
            analyticsURL: "cool://analytics",
            meteredUsageURL: "cool://meteredUsage"
        )

        let remoteConfigData = try! JSONEncoder().encode(remoteConfig)

        let data: [String: Any] = [
            "airship_config": try! JSONSerialization.jsonObject(
                with: remoteConfigData,
                options: []
            )
        ]

        var fromNotification: RemoteConfig?
        self.notificationCenter.addObserver(
            forName: RemoteConfigManager.remoteConfigUpdatedEvent,
            object: nil,
            queue: nil
        ) { notification in
            fromNotification =
                notification.userInfo?[RemoteConfigManager.remoteConfigKey]
                as? RemoteConfig
        }

        let payload = RemoteDataPayload(
            type: "app_config:ios",
            timestamp: Date(),
            data: try! AirshipJSON.wrap(data),
            remoteDataInfo: nil
        )
        self.testRemoteData.payloads = [payload]

        XCTAssertEqual(remoteConfig, fromNotification)
    }

    func testCombineConfig() throws {
        let platformData: [String: Any] = [
            "contact": "some-config",
            "channel": ["neat"],
        ]

        let commonData: [String: Any] = [
            "contact": "some-other-config",
            "message_center": ["wild"],
        ]
        let platformPayload = RemoteDataPayload(
            type: "app_config:ios",
            timestamp: Date(),
            data: try! AirshipJSON.wrap(platformData),
            remoteDataInfo: nil
        )
        let commonPayload = RemoteDataPayload(
            type: "app_config",
            timestamp: Date(),
            data: try! AirshipJSON.wrap(commonData),
            remoteDataInfo: nil
        )

        self.testRemoteData.payloads = [
            commonPayload, platformPayload,
        ]

        XCTAssertEqual(
            "some-config",
            self.testModuleAdapter.moduleConfig[.contact] as! String
        )
        XCTAssertEqual(
            ["neat"],
            self.testModuleAdapter.moduleConfig[.channel] as! [String]
        )
        XCTAssertEqual(
            ["wild"],
            self.testModuleAdapter.moduleConfig[.messageCenter] as! [String]
        )
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
                    "sdk_versions": [AirshipVersion.get()],
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
            remoteData: self.testRemoteData,
            privacyManager: self.privacyManager,
            meteredUsage: AirshipMeteredUsage.test(dataStore: dataStore, privacyManager: privacyManager),
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
}

extension AirshipMeteredUsage {
    static func test(
        dataStore: PreferenceDataStore,
        privacyManager: AirshipPrivacyManager
    ) -> AirshipMeteredUsage {
        return AirshipMeteredUsage(
            dataStore: dataStore,
            channel: TestChannel(),
            privacyManager: privacyManager,
            client: MeteredTestApiClient(),
            store: MeteredUsageStore(appKey: "test.app.key", inMemory: true),
            workManager: TestWorkManager(),
            notificationCenter: AirshipNotificationCenter()
        )
    }
}
