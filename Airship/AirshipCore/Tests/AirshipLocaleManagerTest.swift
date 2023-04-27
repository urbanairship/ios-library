/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

final class AirshipLocaleManagerTest: XCTestCase {

    private let notificaitonCenter: AirshipNotificationCenter = AirshipNotificationCenter(
        notificationCenter: NotificationCenter()
    )
    private let dataStore: PreferenceDataStore = PreferenceDataStore(
        appKey: UUID().uuidString
    )
    private var localeManager: AirshipLocaleManager!

    override func setUpWithError() throws {
        localeManager = AirshipLocaleManager(
            dataStore: dataStore,
            notificationCenter: notificaitonCenter
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

    func testNotificationWhenOverrideChanges() {
        let expectation = self.expectation(description: "update called")
        self.notificaitonCenter.addObserver(
            forName: AirshipLocaleManager.localeUpdatedEvent
        ) { _ in
            expectation.fulfill()
        }

        localeManager.currentLocale = Locale(identifier: "fr")

        self.waitForExpectations(timeout: 10.0)
    }

    func testNotificationWhenOverrideClears() {
        localeManager.currentLocale = Locale(identifier: "fr")

        let expectation = self.expectation(description: "update called")
        self.notificaitonCenter.addObserver(
            forName: AirshipLocaleManager.localeUpdatedEvent
        ) { _ in
            expectation.fulfill()
        }

        localeManager.clearLocale()

        self.waitForExpectations(timeout: 10.0)
    }

    func testNotificationWhenAutoUpdateChanges() {
        let expectation = self.expectation(description: "update called")
        self.notificaitonCenter.addObserver(
            forName: AirshipLocaleManager.localeUpdatedEvent
        ) { _ in
            expectation.fulfill()
        }

        self.notificaitonCenter.post(name: NSLocale.currentLocaleDidChangeNotification)

        self.waitForExpectations(timeout: 10.0)
    }

}
