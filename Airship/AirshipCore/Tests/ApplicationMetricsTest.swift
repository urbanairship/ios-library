/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore

final class ApplicationMetricsTest: XCTestCase {

    private let date: UATestDate = UATestDate(offset: 0, dateOverride: Date())
    private let notificationCenter: NotificationCenter = NotificationCenter()
    private let dataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private var privacyManager: AirshipPrivacyManager!
    private var metrics: ApplicationMetrics!

    override func setUpWithError() throws {
        self.privacyManager = AirshipPrivacyManager(
            dataStore: dataStore,
            defaultEnabledFeatures: .all,
            notificationCenter: notificationCenter
        )

        self.metrics = ApplicationMetrics(
            dataStore: self.dataStore,
            privacyManager: self.privacyManager,
            notificationCenter: self.notificationCenter,
            date: self.date,
            appVersion: "1.0.0"
        )
    }

    func testApplicationActive() throws {
        XCTAssertNil(self.metrics.lastApplicationOpenDate)
        self.notificationCenter.post(name: AppStateTracker.didBecomeActiveNotification, object: nil)
        XCTAssertEqual(self.date.now, self.metrics.lastApplicationOpenDate)
    }


    func testAppVersionUpdated() throws {
        // Fresh install
        XCTAssertFalse(self.metrics.isAppVersionUpdated)

        // No change
        self.metrics = ApplicationMetrics(
            dataStore: self.dataStore,
            privacyManager: self.privacyManager,
            notificationCenter: self.notificationCenter,
            date: self.date,
            appVersion: "1.0.0"
        )
        XCTAssertFalse(self.metrics.isAppVersionUpdated)

        // Update
        self.metrics = ApplicationMetrics(
            dataStore: self.dataStore,
            privacyManager: self.privacyManager,
            notificationCenter: self.notificationCenter,
            date: self.date,
            appVersion: "2.0.0"
        )
        XCTAssertTrue(self.metrics.isAppVersionUpdated)
    }

    func testOptedOut() {
        self.notificationCenter.post(name: AppStateTracker.didBecomeActiveNotification, object: nil)
        XCTAssertEqual(self.date.now, self.metrics.lastApplicationOpenDate)

        self.privacyManager.enabledFeatures = [.analytics, .push]
        XCTAssertEqual(self.date.now, self.metrics.lastApplicationOpenDate)

        self.privacyManager.enabledFeatures = [.inAppAutomation, .push]
        XCTAssertEqual(self.date.now, self.metrics.lastApplicationOpenDate)

        self.privacyManager.enabledFeatures = .push
        XCTAssertNil(self.metrics.lastApplicationOpenDate)
    }
}
