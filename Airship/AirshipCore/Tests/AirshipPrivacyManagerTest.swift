import Testing
@_spi(AirshipInternal) import AirshipBasement
import Foundation

@testable
@_spi(AirshipInternal) import AirshipCore

@Suite
struct DefaultAirshipPrivacyManagerTest {
    private let dataStore: PreferenceDataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private let notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter(notificationCenter: NotificationCenter())

    private let config: RuntimeConfig = RuntimeConfig.testConfig()

    private let privacyManager: DefaultAirshipPrivacyManager

    init() async throws {
        self.privacyManager = await DefaultAirshipPrivacyManager(
            dataStore: dataStore,
            config: self.config,
            defaultEnabledFeatures: .all,
            notificationCenter: notificationCenter
        )
    }

    @Test
    func testDefaultFeatures() async {
        #expect(self.privacyManager.enabledFeatures == .all)

        let privacyManager = await DefaultAirshipPrivacyManager(
            dataStore: dataStore,
            config: self.config,
            defaultEnabledFeatures: [],
            notificationCenter: notificationCenter
        )

        #expect(privacyManager.enabledFeatures == [])
    }

    @Test
    func testEnableFeatures() {
        self.privacyManager.disableFeatures(.all)

        #expect(self.privacyManager.enabledFeatures == [])

        self.privacyManager.enableFeatures(.push)
        #expect(self.privacyManager.enabledFeatures == [.push])

        self.privacyManager.enableFeatures([.push, .contacts])
        #expect(self.privacyManager.enabledFeatures == [.push, .contacts])
    }

    @Test
    func testDisableFeatures() {
        #expect(self.privacyManager.enabledFeatures == .all)

        self.privacyManager.disableFeatures(.push)
        #expect(self.privacyManager.enabledFeatures != .all)

        self.privacyManager.disableFeatures([.analytics, .messageCenter, .tagsAndAttributes])
        #expect(self.privacyManager.enabledFeatures == [.inAppAutomation, .contacts, .featureFlags, .onDeviceAI])
    }

    @Test
    func testIsEnabled() {
        self.privacyManager.disableFeatures(.all)

        #expect(!(self.privacyManager.isEnabled(.analytics)))

        self.privacyManager.enableFeatures(.contacts)
        #expect(self.privacyManager.isEnabled(.contacts))

        self.privacyManager.enableFeatures(.analytics)
        #expect(self.privacyManager.isEnabled(.analytics))

        self.privacyManager.enableFeatures(.all)
        #expect(self.privacyManager.isEnabled(.inAppAutomation))
    }

    @Test
    func testIsAnyEnabled() {
        #expect(self.privacyManager.isAnyFeatureEnabled(ignoringRemoteConfig: false))

        self.privacyManager.disableFeatures([.push, .contacts])
        #expect(self.privacyManager.isAnyFeatureEnabled(ignoringRemoteConfig: false))

        self.privacyManager.disableFeatures(.all)
        #expect(!(self.privacyManager.isAnyFeatureEnabled(ignoringRemoteConfig: false)))
    }

    @Test
    func testNoneEnabled() {
        self.privacyManager.enabledFeatures = []
        #expect(!(self.privacyManager.isAnyFeatureEnabled(ignoringRemoteConfig: false)))

        self.privacyManager.enableFeatures([.push, .tagsAndAttributes])
        #expect(self.privacyManager.isAnyFeatureEnabled(ignoringRemoteConfig: false))

        self.privacyManager.enabledFeatures = []
        #expect(!(self.privacyManager.isAnyFeatureEnabled(ignoringRemoteConfig: false)))
    }

    @Test
    func testSetEnabled() {
        self.privacyManager.enabledFeatures = .contacts

        #expect(self.privacyManager.isEnabled(.contacts))
        #expect(!(self.privacyManager.isEnabled(.analytics)))

        self.privacyManager.enabledFeatures = .analytics
        #expect(self.privacyManager.isEnabled(.analytics))
    }

    @Test
    @MainActor
    func testRemoteConfigOverrides() async {
        #expect(AirshipFeature.all == self.privacyManager.enabledFeatures)

        self.config.updateRemoteConfig(
            RemoteConfig(disabledFeatures: .push)
        )

        #expect(AirshipFeature.all.subtracting(.push) == self.privacyManager.enabledFeatures)

        self.config.updateRemoteConfig(
            RemoteConfig(disabledFeatures: [])
        )

        #expect(AirshipFeature.all == self.privacyManager.enabledFeatures)

        self.config.updateRemoteConfig(
            RemoteConfig(disabledFeatures: .all)
        )

        #expect([] == self.privacyManager.enabledFeatures)
    }


    @Test
    @MainActor
    func testNotifiedOnChange() {
        let counter = AirshipAtomicValue(0)
        let observer = notificationCenter.addObserver(forName: AirshipNotifications.PrivacyManagerUpdated.name, object: nil, queue: nil) { @Sendable _ in
            counter.update { $0 += 1 }
        }

        self.privacyManager.enabledFeatures = .all
        self.privacyManager.disableFeatures([])
        self.privacyManager.enableFeatures(.all)
        self.privacyManager.enableFeatures(.analytics)
        #expect(counter.value == 0)

        self.privacyManager.disableFeatures(.analytics)
        #expect(counter.value == 1)

        self.privacyManager.enableFeatures(.analytics)
        #expect(counter.value == 2)

        self.config.updateRemoteConfig(
            RemoteConfig(disabledFeatures: [])
        )
        #expect(counter.value == 2)


        self.config.updateRemoteConfig(
            RemoteConfig(disabledFeatures: [.analytics])
        )
        #expect(counter.value == 3)


        notificationCenter.removeObserver(observer)

    }
}
