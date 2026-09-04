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

    /// Enabling a feature while another is remotely disabled must not persist the
    /// remote-config subtraction — the remotely disabled feature has to come back
    /// once the remote disablement is lifted.
    @Test
    @MainActor
    func testEnableFeaturesDoesNotPersistRemoteDisabledFeatures() async {
        self.config.updateRemoteConfig(
            RemoteConfig(disabledFeatures: .analytics)
        )

        self.privacyManager.enableFeatures(.push)
        #expect(self.privacyManager.enabledFeatures == AirshipFeature.all.subtracting(.analytics))

        self.config.updateRemoteConfig(
            RemoteConfig(disabledFeatures: [])
        )

        #expect(self.privacyManager.enabledFeatures == .all)
    }

    /// Same as above through `disableFeatures`: only the requested feature may be
    /// removed from the local set.
    @Test
    @MainActor
    func testDisableFeaturesDoesNotPersistRemoteDisabledFeatures() async {
        self.config.updateRemoteConfig(
            RemoteConfig(disabledFeatures: .analytics)
        )

        self.privacyManager.disableFeatures(.push)
        #expect(
            self.privacyManager.enabledFeatures == AirshipFeature.all.subtracting([.analytics, .push])
        )

        self.config.updateRemoteConfig(
            RemoteConfig(disabledFeatures: [])
        )

        #expect(self.privacyManager.enabledFeatures == AirshipFeature.all.subtracting(.push))
    }

    /// `migrateData` runs inside `init` and calls `disableFeatures`, so it must not
    /// bake in features that are remotely disabled at takeOff.
    @Test
    @MainActor
    func testMigrateDataDoesNotPersistRemoteDisabledFeatures() async {
        let dataStore = PreferenceDataStore(appKey: UUID().uuidString)
        dataStore.setBool(false, forKey: "UAAnalyticsEnabled")

        let config = RuntimeConfig.testConfig()
        config.updateRemoteConfig(
            RemoteConfig(disabledFeatures: .push)
        )

        let privacyManager = DefaultAirshipPrivacyManager(
            dataStore: dataStore,
            config: config,
            defaultEnabledFeatures: .all,
            notificationCenter: notificationCenter
        )

        #expect(
            privacyManager.enabledFeatures == AirshipFeature.all.subtracting([.analytics, .push])
        )

        config.updateRemoteConfig(
            RemoteConfig(disabledFeatures: [])
        )

        // Analytics stays off — that is the migrated legacy value. Push comes back.
        #expect(privacyManager.enabledFeatures == AirshipFeature.all.subtracting(.analytics))
    }

    /// The read-modify-write has to happen under the lock, otherwise concurrent
    /// enables lose updates.
    @Test
    func testConcurrentEnableFeatures() async {
        self.privacyManager.disableFeatures(.all)
        #expect(self.privacyManager.enabledFeatures == [])

        let features: [AirshipFeature] = [
            .inAppAutomation,
            .messageCenter,
            .push,
            .analytics,
            .tagsAndAttributes,
            .contacts,
            .featureFlags,
            .onDeviceAI
        ]

        await withTaskGroup(of: Void.self) { group in
            for feature in features {
                group.addTask {
                    self.privacyManager.enableFeatures(feature)
                }
            }
        }

        #expect(self.privacyManager.enabledFeatures == .all)
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
