/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable @_spi(AirshipInternal) import AirshipAutomation
@testable import AirshipCore

struct ApplicationMetricsTest {

    private let notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter(
        notificationCenter: NotificationCenter()
    )
    private let dataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private let privacyManager: TestPrivacyManager
    private let metrics: ApplicationMetrics

    init() {
        self.privacyManager = TestPrivacyManager(
            dataStore: self.dataStore,
            config: .testConfig(),
            defaultEnabledFeatures: .all,
            notificationCenter: self.notificationCenter
        )

        self.metrics = ApplicationMetrics(
            dataStore: self.dataStore,
            privacyManager: self.privacyManager,
            notificationCenter: self.notificationCenter,
            appVersion: "1.0.0"
        )
    }


    @Test
    func testAppVersionUpdated() throws {
        var metrics = self.metrics
        // Fresh install
        #expect(!(metrics.isAppVersionUpdated))

        // No change
        metrics = ApplicationMetrics(
            dataStore: self.dataStore,
            privacyManager: self.privacyManager,
            notificationCenter: self.notificationCenter,
            appVersion: "1.0.0"
        )
        #expect(!(metrics.isAppVersionUpdated))

        // Update
        metrics = ApplicationMetrics(
            dataStore: self.dataStore,
            privacyManager: self.privacyManager,
            notificationCenter: self.notificationCenter,
            appVersion: "2.0.0"
        )


        #expect(metrics.isAppVersionUpdated)
    }

    @Test
    func testOptedOut() {
        // Update
        let metrics = ApplicationMetrics(
            dataStore: self.dataStore,
            privacyManager: self.privacyManager,
            notificationCenter: self.notificationCenter,
            appVersion: "2.0.0"
        )

        #expect(metrics.isAppVersionUpdated)

        self.privacyManager.enabledFeatures = [.analytics, .push]
        #expect(metrics.isAppVersionUpdated)

        self.privacyManager.enabledFeatures = [.inAppAutomation, .push]
        #expect(metrics.isAppVersionUpdated)

        self.privacyManager.enabledFeatures = .push
        #expect(!(metrics.isAppVersionUpdated))
    }
}
