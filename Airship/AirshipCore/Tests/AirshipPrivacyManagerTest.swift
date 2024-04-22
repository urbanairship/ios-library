import XCTest

@testable
import AirshipCore

class AirshipPrivacyManagerTest: XCTestCase {
    private let dataStore: PreferenceDataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private let notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter(notificationCenter: NotificationCenter())

    private var config: RuntimeConfig!
    private var privacyManager: AirshipPrivacyManager!
    override func setUp() async throws {
        self.config = RuntimeConfig(config: AirshipConfig(), dataStore: dataStore)
        self.privacyManager = await AirshipPrivacyManager(
            dataStore: dataStore,
            config: self.config,
            defaultEnabledFeatures: .all,
            notificationCenter: notificationCenter
        )
    }

    func testDefaultFeatures() async {
        XCTAssertEqual(self.privacyManager.enabledFeatures, .all)

        self.privacyManager = await AirshipPrivacyManager(
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
        XCTAssertEqual(self.privacyManager.enabledFeatures, [.inAppAutomation, .contacts])
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
        XCTAssertTrue(self.privacyManager.isAnyFeatureEnabled())

        self.privacyManager.disableFeatures([.push, .contacts])
        XCTAssertTrue(self.privacyManager.isAnyFeatureEnabled())

        self.privacyManager.disableFeatures(.all)
        XCTAssertFalse(self.privacyManager.isAnyFeatureEnabled())
    }

    func testNoneEnabled() {
        self.privacyManager.enabledFeatures = []
        XCTAssertFalse(self.privacyManager.isAnyFeatureEnabled())

        self.privacyManager.enableFeatures([.push, .tagsAndAttributes])
        XCTAssertTrue(self.privacyManager.isAnyFeatureEnabled())

        self.privacyManager.enabledFeatures = []
        XCTAssertFalse(self.privacyManager.isAnyFeatureEnabled())
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
        var eventCount = 0
        let observer = notificationCenter.addObserver(forName: AirshipNotifications.PrivacyManagerUpdated.name, object: nil, queue: nil) { _ in
            eventCount += 1
        }

        self.privacyManager.enabledFeatures = .all
        self.privacyManager.disableFeatures([])
        self.privacyManager.enableFeatures(.all)
        self.privacyManager.enableFeatures(.analytics)
        XCTAssertEqual(eventCount, 0)

        self.privacyManager.disableFeatures(.analytics)
        XCTAssertEqual(eventCount, 1)

        self.privacyManager.enableFeatures(.analytics)
        XCTAssertEqual(eventCount, 2)

        self.config.updateRemoteConfig(
            RemoteConfig(disabledFeatures: [])
        )
        XCTAssertEqual(eventCount, 2)


        self.config.updateRemoteConfig(
            RemoteConfig(disabledFeatures: [.analytics])
        )
        XCTAssertEqual(eventCount, 3)


        notificationCenter.removeObserver(observer)

    }
    
}
