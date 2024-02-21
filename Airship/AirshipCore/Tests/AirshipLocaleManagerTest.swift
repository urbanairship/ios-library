/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

final class AirshipLocaleManagerTest: XCTestCase {

    private let notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter(
        notificationCenter: NotificationCenter()
    )
    private let dataStore: PreferenceDataStore = PreferenceDataStore(
        appKey: UUID().uuidString
    )
    private var config: RuntimeConfig!
    private var localeManager: AirshipLocaleManager!

    override func setUpWithError() throws {
        config = RuntimeConfig(
                   config: AirshipConfig(),
                   dataStore: dataStore
               )
        localeManager = AirshipLocaleManager(
            dataStore: dataStore,
            config: config,
            notificationCenter: notificationCenter
        )
    }

    func testLocale() throws {
        XCTAssertEqual(self.localeManager.currentLocale, Locale.autoupdatingCurrent)

        let french = Locale(identifier: "fr")
        localeManager.currentLocale = french
        XCTAssertEqual(self.localeManager.currentLocale, french)

        let english = Locale(identifier: "en")
        localeManager.currentLocale = english
        XCTAssertEqual(self.localeManager.currentLocale, english)

        localeManager.clearLocale()
        XCTAssertEqual(self.localeManager.currentLocale, Locale.autoupdatingCurrent)
    }
    
    func testLocaleWithUseUserPreferredLocale() throws {
        config.useUserPreferredLocale = true
        let preferredLocale = Locale(identifier: Locale.preferredLanguages[0])
        XCTAssertEqual(self.localeManager.currentLocale, preferredLocale)
        
        let french = Locale(identifier: "fr")
        localeManager.currentLocale = french
        XCTAssertEqual(self.localeManager.currentLocale, french)
        
        localeManager.clearLocale()
        XCTAssertEqual(self.localeManager.currentLocale, preferredLocale)
    }

    func testNotificationWhenOverrideChanges() {
        let expectation = self.expectation(description: "update called")
        self.notificationCenter.addObserver(
            forName: AirshipNotifications.localeUpdatedEvent
        ) { _ in
            expectation.fulfill()
        }

        localeManager.currentLocale = Locale(identifier: "fr")

        self.waitForExpectations(timeout: 10.0)
    }

    func testNotificationWhenOverrideClears() {
        localeManager.currentLocale = Locale(identifier: "fr")

        let expectation = self.expectation(description: "update called")
        self.notificationCenter.addObserver(
            forName: AirshipNotifications.localeUpdatedEvent
        ) { _ in
            expectation.fulfill()
        }

        localeManager.clearLocale()

        self.waitForExpectations(timeout: 10.0)
    }

    func testNotificationWhenAutoUpdateChanges() {
        let expectation = self.expectation(description: "update called")
        self.notificationCenter.addObserver(
            forName: AirshipNotifications.localeUpdatedEvent
        ) { _ in
            expectation.fulfill()
        }

        self.notificationCenter.post(name: NSLocale.currentLocaleDidChangeNotification)

        self.waitForExpectations(timeout: 10.0)
    }

}
