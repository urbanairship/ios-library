/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

final class AirshipLocaleManagerTest: XCTestCase {

    private let notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter(
        notificationCenter: NotificationCenter()
    )

    private func makeLocaleManager(
        useUserPreferredLocale: Bool = false
    ) -> AirshipLocaleManager {
        return AirshipLocaleManager(
            dataStore: PreferenceDataStore(
                appKey: UUID().uuidString
            ),
            config: .testConfig(useUserPreferredLocale: useUserPreferredLocale),
            notificationCenter: notificationCenter
        )
    }

    func testLocale() throws {
        let localeManager = makeLocaleManager()
        XCTAssertEqual(localeManager.currentLocale, Locale.autoupdatingCurrent)

        let french = Locale(identifier: "fr")
        localeManager.currentLocale = french
        XCTAssertEqual(localeManager.currentLocale, french)

        let english = Locale(identifier: "en")
        localeManager.currentLocale = english
        XCTAssertEqual(localeManager.currentLocale, english)

        localeManager.clearLocale()
        XCTAssertEqual(localeManager.currentLocale, Locale.autoupdatingCurrent)
    }
    
    func testLocaleWithUseUserPreferredLocale() throws {
        let localeManager = makeLocaleManager(useUserPreferredLocale: true)
        let preferredLocale = Locale(identifier: Locale.preferredLanguages[0])
        XCTAssertEqual(localeManager.currentLocale, preferredLocale)
        
        let french = Locale(identifier: "fr")
        localeManager.currentLocale = french
        XCTAssertEqual(localeManager.currentLocale, french)
        
        localeManager.clearLocale()
        XCTAssertEqual(localeManager.currentLocale, preferredLocale)
    }

    func testNotificationWhenOverrideChanges() {
        let localeManager = makeLocaleManager()

        let expectation = self.expectation(description: "update called")
        self.notificationCenter.addObserver(
            forName: AirshipNotifications.LocaleUpdated.name
        ) { _ in
            expectation.fulfill()
        }

        localeManager.currentLocale = Locale(identifier: "fr")

        self.waitForExpectations(timeout: 10.0)
    }

    func testNotificationWhenOverrideClears() {
        let localeManager = makeLocaleManager()

        localeManager.currentLocale = Locale(identifier: "fr")

        let expectation = self.expectation(description: "update called")
        
        self.notificationCenter.addObserver(
            forName: AirshipNotifications.LocaleUpdated.name
        ) { _ in
            expectation.fulfill()
        }

        localeManager.clearLocale()

        self.waitForExpectations(timeout: 10.0)
    }

    func testNotificationWhenAutoUpdateChanges() {
        let localeManager = makeLocaleManager()
        let expectation = self.expectation(description: "update called")
        self.notificationCenter.addObserver(
            forName: AirshipNotifications.LocaleUpdated.name
        ) { _ in
            expectation.fulfill()
        }

        self.notificationCenter.post(name: NSLocale.currentLocaleDidChangeNotification)

        self.waitForExpectations(timeout: 10.0)
    }

}
