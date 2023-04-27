import XCTest

@testable import AirshipCore

class RemoteConfigManagerTest: XCTestCase {

    let dataStore = PreferenceDataStore(appKey: UUID().uuidString)
    let testRemoteDataProvider = TestRemoteDataProvider()
    let testModuleAdapter = TestRemoteConfigModuleAdapter()
    let notificationCenter = AirshipNotificationCenter.shared

    var privacyManager: AirshipPrivacyManager!
    var remoteConfigManager: RemoteConfigManager!

    var appVersion = ""

    override func setUpWithError() throws {
        self.privacyManager = AirshipPrivacyManager(
            dataStore: self.dataStore,
            defaultEnabledFeatures: .all,
            notificationCenter: self.notificationCenter
        )

        self.remoteConfigManager = RemoteConfigManager(
            remoteDataManager: self.testRemoteDataProvider,
            privacyManager: self.privacyManager,
            moduleAdapter: self.testModuleAdapter,
            notificationCenter: self.notificationCenter,
            versionBlock: { [weak self] in return self?.appVersion ?? "" }
        )

    }

    func testSusbcription() throws {
        XCTAssertEqual(2, self.testRemoteDataProvider.subscribers.count)

        self.privacyManager.enabledFeatures = []
        XCTAssertEqual(0, self.testRemoteDataProvider.subscribers.count)

        self.privacyManager.enabledFeatures = .analytics
        XCTAssertEqual(2, self.testRemoteDataProvider.subscribers.count)
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
            data: data,
            metadata: nil
        )
        self.testRemoteDataProvider.dispatchPayload(payload)

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
            data: [:],
            metadata: nil
        )
        self.testRemoteDataProvider.dispatchPayload(payload)

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
            self.testRemoteDataProvider.remoteDataRefreshInterval
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
            data: data,
            metadata: nil
        )
        self.testRemoteDataProvider.dispatchPayload(payload)
        XCTAssertEqual(
            100.0,
            self.testRemoteDataProvider.remoteDataRefreshInterval
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
            data: data,
            metadata: nil
        )
        self.testRemoteDataProvider.dispatchPayload(payload)

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
            chatURL: "cool://chat",
            chatWebSocketURL: "cool://chatWebSocket"
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
            data: data,
            metadata: nil
        )
        self.testRemoteDataProvider.dispatchPayload(payload)

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
            data: platformData,
            metadata: nil
        )
        let commonPayload = RemoteDataPayload(
            type: "app_config",
            timestamp: Date(),
            data: commonData,
            metadata: nil
        )

        self.testRemoteDataProvider.dispatchPayloads([
            commonPayload, platformPayload,
        ])

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
                ],
                [
                    "modules": ["contact"],
                    "app_versions": [
                        "value": ["version_matches": "[1.0, 8.0]"],
                        "scope": ["ios", "version"],
                    ],
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
            data: data,
            metadata: nil
        )

        self.appVersion = "0.0.0"
        self.testRemoteDataProvider.dispatchPayload(payload)

        var expectedDisable: [RemoteConfigModule] = [
            .analytics, .messageCenter, .inAppAutomation,
        ]
        XCTAssertEqual(
            Set(expectedDisable),
            self.testModuleAdapter.disabledModules
        )
        XCTAssertEqual(
            100.0,
            self.testRemoteDataProvider.remoteDataRefreshInterval
        )

        self.appVersion = "2.0.0"
        self.testRemoteDataProvider.dispatchPayload(payload)
        expectedDisable = [
            .analytics, .contact, .messageCenter, .inAppAutomation,
        ]
        XCTAssertEqual(
            Set(expectedDisable),
            self.testModuleAdapter.disabledModules
        )
        XCTAssertEqual(
            200.0,
            self.testRemoteDataProvider.remoteDataRefreshInterval
        )
    }
}
