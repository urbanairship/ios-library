import XCTest

@testable
import AirshipCore

class DefaultAirshipPrivacyManagerTest: XCTestCase {
    private let dataStore: PreferenceDataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private let notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter(notificationCenter: NotificationCenter())

    private var config: RuntimeConfig = RuntimeConfig.testConfig()

    private var privacyManager: DefaultAirshipPrivacyManager!
    override func setUp() async throws {
        self.privacyManager = await DefaultAirshipPrivacyManager(
            dataStore: dataStore,
            config: self.config,
            defaultEnabledFeatures: .all,
            notificationCenter: notificationCenter
        )
    }

    func testDefaultFeatures() async {
        XCTAssertEqual(self.privacyManager.enabledFeatures, .all)

        self.privacyManager = await DefaultAirshipPrivacyManager(
            dataStore: dataStore,
            config: self.config,
            defaultEnabledFeatures: [],
            notificationCenter: notificationCenter
        )

        XCTAssertEqual(self.privacyManager.enabledFeatures, [])
    }

    func testEnableFeatures() {
        self.privacyManager.disableFeatures(.all)

        XCTAssertEqual(self.privacyManager.enabledFeatures, [])

        self.privacyManager.enableFeatures(.push)
        XCTAssertEqual(self.privacyManager.enabledFeatures, [.push])

        self.privacyManager.enableFeatures([.push, .contacts])
        XCTAssertEqual(self.privacyManager.enabledFeatures, [.push, .contacts])
    }

    func testDisableFeatures() {
        XCTAssertEqual(self.privacyManager.enabledFeatures, .all)

        self.privacyManager.disableFeatures(.push)
        XCTAssertNotEqual(self.privacyManager.enabledFeatures, .all)

        self.privacyManager.disableFeatures([.analytics, .messageCenter, .tagsAndAttributes])
        XCTAssertEqual(self.privacyManager.enabledFeatures, [.inAppAutomation, .contacts, .featureFlags])
    }

    func testIsEnabled() {
        self.privacyManager.disableFeatures(.all)

        XCTAssertFalse(self.privacyManager.isEnabled(.analytics))

        self.privacyManager.enableFeatures(.contacts)
        XCTAssertTrue(self.privacyManager.isEnabled(.contacts))

        self.privacyManager.enableFeatures(.analytics)
        XCTAssertTrue(self.privacyManager.isEnabled(.analytics))

        self.privacyManager.enableFeatures(.all)
        XCTAssertTrue(self.privacyManager.isEnabled(.inAppAutomation))
    }

    func testIsAnyEnabled() {
        XCTAssertTrue(self.privacyManager.isAnyFeatureEnabled(ignoringRemoteConfig: false))

        self.privacyManager.disableFeatures([.push, .contacts])
        XCTAssertTrue(self.privacyManager.isAnyFeatureEnabled(ignoringRemoteConfig: false))

        self.privacyManager.disableFeatures(.all)
        XCTAssertFalse(self.privacyManager.isAnyFeatureEnabled(ignoringRemoteConfig: false))
    }

    func testNoneEnabled() {
        self.privacyManager.enabledFeatures = []
        XCTAssertFalse(self.privacyManager.isAnyFeatureEnabled(ignoringRemoteConfig: false))

        self.privacyManager.enableFeatures([.push, .tagsAndAttributes])
        XCTAssertTrue(self.privacyManager.isAnyFeatureEnabled(ignoringRemoteConfig: false))

        self.privacyManager.enabledFeatures = []
        XCTAssertFalse(self.privacyManager.isAnyFeatureEnabled(ignoringRemoteConfig: false))
    }

    func testSetEnabled() {
        self.privacyManager.enabledFeatures = .contacts

        XCTAssertTrue(self.privacyManager.isEnabled(.contacts))
        XCTAssertFalse(self.privacyManager.isEnabled(.analytics))

        self.privacyManager.enabledFeatures = .analytics
        XCTAssertTrue(self.privacyManager.isEnabled(.analytics))
    }

    func testRemoteConfigOverrides() async {
        XCTAssertEqual(AirshipFeature.all, self.privacyManager.enabledFeatures)

        await self.config.updateRemoteConfig(
            RemoteConfig(disabledFeatures: .push)
        )

        XCTAssertEqual(AirshipFeature.all.subtracting(.push), self.privacyManager.enabledFeatures)

        await self.config.updateRemoteConfig(
            RemoteConfig(disabledFeatures: [])
        )

        XCTAssertEqual(AirshipFeature.all, self.privacyManager.enabledFeatures)

        await self.config.updateRemoteConfig(
            RemoteConfig(disabledFeatures: .all)
        )

        XCTAssertEqual([], self.privacyManager.enabledFeatures)
    }


    @MainActor
    func testNotifiedOnChange() {
        let counter = AirshipAtomicValue(0)
        let observer = notificationCenter.addObserver(forName: AirshipNotifications.PrivacyManagerUpdated.name, object: nil, queue: nil) { @Sendable _ in
            counter.value += 1
        }

        self.privacyManager.enabledFeatures = .all
        self.privacyManager.disableFeatures([])
        self.privacyManager.enableFeatures(.all)
        self.privacyManager.enableFeatures(.analytics)
        XCTAssertEqual(counter.value, 0)

        self.privacyManager.disableFeatures(.analytics)
        XCTAssertEqual(counter.value, 1)

        self.privacyManager.enableFeatures(.analytics)
        XCTAssertEqual(counter.value, 2)

        self.config.updateRemoteConfig(
            RemoteConfig(disabledFeatures: [])
        )
        XCTAssertEqual(counter.value, 2)


        self.config.updateRemoteConfig(
            RemoteConfig(disabledFeatures: [.analytics])
        )
        XCTAssertEqual(counter.value, 3)


        notificationCenter.removeObserver(observer)

    }
}
