/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable @_spi(AirshipInternal) import AirshipAutomation
@_spi(AirshipInternal) @testable import AirshipCore

struct ApplicationMetricsTest {

    private let notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter(
        notificationCenter: NotificationCenter()
    )
    private let dataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private let privacyManager: TestPrivacyManager

    init() {
        self.privacyManager = TestPrivacyManager(
            dataStore: self.dataStore,
            config: .testConfig(),
            defaultEnabledFeatures: .all,
            notificationCenter: self.notificationCenter
        )
    }

    @Test
    func testAppVersionUpdated() throws {
        let initial = ApplicationMetrics(
            dataStore: self.dataStore,
            privacyManager: self.privacyManager,
            notificationCenter: self.notificationCenter,
            appVersion: "1.0.0",
            buildVersion: "1"
        )
        // Fresh install — no previous build version stored
        #expect(!initial.isAppVersionUpdated)

        // No change
        let noChange = ApplicationMetrics(
            dataStore: self.dataStore,
            privacyManager: self.privacyManager,
            notificationCenter: self.notificationCenter,
            appVersion: "1.0.0",
            buildVersion: "1"
        )
        #expect(!noChange.isAppVersionUpdated)

        // Build version bumped (same marketing version)
        let buildBump = ApplicationMetrics(
            dataStore: self.dataStore,
            privacyManager: self.privacyManager,
            notificationCenter: self.notificationCenter,
            appVersion: "1.0.0",
            buildVersion: "2"
        )
        #expect(buildBump.isAppVersionUpdated)

        // Both bumped
        let bothBump = ApplicationMetrics(
            dataStore: self.dataStore,
            privacyManager: self.privacyManager,
            notificationCenter: self.notificationCenter,
            appVersion: "2.0.0",
            buildVersion: "3"
        )
        #expect(bothBump.isAppVersionUpdated)
    }

    @Test
    func testPreviousVersionsExposedOnUpgrade() throws {
        // First launch — stores version
        _ = ApplicationMetrics(
            dataStore: self.dataStore,
            privacyManager: self.privacyManager,
            notificationCenter: self.notificationCenter,
            appVersion: "1.0.0",
            buildVersion: "1"
        )

        // Upgrade
        let metrics = ApplicationMetrics(
            dataStore: self.dataStore,
            privacyManager: self.privacyManager,
            notificationCenter: self.notificationCenter,
            appVersion: "2.0.0",
            buildVersion: "2"
        )

        #expect(metrics.isAppVersionUpdated)
        #expect(metrics.lastAppVersion == "1.0.0")
        #expect(metrics.lastBuildVersion == "1")
    }

    @Test
    func testExistingInstallWithoutBuildVersionDoesNotFire() throws {
        // Old install — only marketing version was stored, no build version
        _ = ApplicationMetrics(
            dataStore: self.dataStore,
            privacyManager: self.privacyManager,
            notificationCenter: self.notificationCenter,
            appVersion: "1.0.0",
            buildVersion: nil
        )

        // Still no build version available — can't compare, does not fire.
        let metrics = ApplicationMetrics(
            dataStore: self.dataStore,
            privacyManager: self.privacyManager,
            notificationCenter: self.notificationCenter,
            appVersion: "2.0.0",
            buildVersion: nil
        )
        #expect(!metrics.isAppVersionUpdated)
    }

    @Test
    func testOptedOut() {
        // First store a version so we're not on a fresh install
        _ = ApplicationMetrics(
            dataStore: self.dataStore,
            privacyManager: self.privacyManager,
            notificationCenter: self.notificationCenter,
            appVersion: "1.0.0",
            buildVersion: "1"
        )

        // Upgrade
        let metrics = ApplicationMetrics(
            dataStore: self.dataStore,
            privacyManager: self.privacyManager,
            notificationCenter: self.notificationCenter,
            appVersion: "2.0.0",
            buildVersion: "2"
        )

        #expect(metrics.isAppVersionUpdated)

        self.privacyManager.enabledFeatures = [.analytics, .push]
        #expect(metrics.isAppVersionUpdated)

        self.privacyManager.enabledFeatures = [.inAppAutomation, .push]
        #expect(metrics.isAppVersionUpdated)

        self.privacyManager.enabledFeatures = .push
        #expect(!metrics.isAppVersionUpdated)
    }
}
