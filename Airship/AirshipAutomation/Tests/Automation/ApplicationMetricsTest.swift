/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipAutomation
@testable import AirshipCore

final class ApplicationMetricsTest: XCTestCase {

    private let notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter(
        notificationCenter: NotificationCenter()
    )
    private let dataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private var privacyManager: AirshipPrivacyManager!
    private var metrics: ApplicationMetrics!

    override func setUp() async throws {
        self.privacyManager = await AirshipPrivacyManager(
            dataStore: self.dataStore,
            config:  RuntimeConfig(
                config: AirshipConfig(),
                dataStore: self.dataStore
            ),
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


    func testAppVersionUpdated() throws {
        // Fresh install
        XCTAssertFalse(self.metrics.isAppVersionUpdated)

        // No change
        self.metrics = ApplicationMetrics(
            dataStore: self.dataStore,
            privacyManager: self.privacyManager,
            notificationCenter: self.notificationCenter,
            appVersion: "1.0.0"
        )
        XCTAssertFalse(self.metrics.isAppVersionUpdated)

        // Update
        self.metrics = ApplicationMetrics(
            dataStore: self.dataStore,
            privacyManager: self.privacyManager,
            notificationCenter: self.notificationCenter,
            appVersion: "2.0.0"
        )


        XCTAssertTrue(self.metrics.isAppVersionUpdated)
    }

    func testOptedOut() {
        // Update
        self.metrics = ApplicationMetrics(
            dataStore: self.dataStore,
            privacyManager: self.privacyManager,
            notificationCenter: self.notificationCenter,
            appVersion: "2.0.0"
        )

        XCTAssertTrue(self.metrics.isAppVersionUpdated)

        self.privacyManager.enabledFeatures = [.analytics, .push]
        XCTAssertTrue(self.metrics.isAppVersionUpdated)

        self.privacyManager.enabledFeatures = [.inAppAutomation, .push]
        XCTAssertTrue(self.metrics.isAppVersionUpdated)

        self.privacyManager.enabledFeatures = .push
        XCTAssertFalse(self.metrics.isAppVersionUpdated)
    }
}
