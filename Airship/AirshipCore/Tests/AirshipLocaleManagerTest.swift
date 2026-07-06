/* Copyright Airship and Contributors */

import Testing

@testable
@_spi(AirshipInternal) import AirshipCore
import Foundation

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct AirshipLocaleManagerTest {

    private let notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter(
        notificationCenter: NotificationCenter()
    )

    private func makeLocaleManager(
        useUserPreferredLocale: Bool = false
    ) -> DefaultAirshipLocaleManager {
        return DefaultAirshipLocaleManager(
            dataStore: PreferenceDataStore(
                appKey: UUID().uuidString
            ),
            config: .testConfig(useUserPreferredLocale: useUserPreferredLocale),
            notificationCenter: notificationCenter
        )
    }

    @Test
    func testLocale() throws {
        let localeManager = makeLocaleManager()
        #expect(localeManager.currentLocale == Locale.autoupdatingCurrent)

        let french = Locale(identifier: "fr")
        localeManager.currentLocale = french
        #expect(localeManager.currentLocale == french)

        let english = Locale(identifier: "en")
        localeManager.currentLocale = english
        #expect(localeManager.currentLocale == english)

        localeManager.clearLocale()
        #expect(localeManager.currentLocale == Locale.autoupdatingCurrent)
    }
    
    @Test
    func testLocaleWithUseUserPreferredLocale() throws {
        let localeManager = makeLocaleManager(useUserPreferredLocale: true)
        let preferredLocale = Locale(identifier: Locale.preferredLanguages[0])
        #expect(localeManager.currentLocale == preferredLocale)
        
        let french = Locale(identifier: "fr")
        localeManager.currentLocale = french
        #expect(localeManager.currentLocale == french)
        
        localeManager.clearLocale()
        #expect(localeManager.currentLocale == preferredLocale)
    }

    @Test
    func testNotificationWhenOverrideChanges() async {
        let localeManager = makeLocaleManager()

        let expectation = AirshipTestExpectation(description: "update called")
        self.notificationCenter.addObserver(
            forName: AirshipNotifications.LocaleUpdated.name
        ) { _ in
            expectation.fulfill()
        }

        localeManager.currentLocale = Locale(identifier: "fr")

        await fulfillment(of: [expectation], timeout: 10.0)
    }

    @Test
    func testNotificationWhenOverrideClears() async {
        let localeManager = makeLocaleManager()

        localeManager.currentLocale = Locale(identifier: "fr")

        let expectation = AirshipTestExpectation(description: "update called")
        
        self.notificationCenter.addObserver(
            forName: AirshipNotifications.LocaleUpdated.name
        ) { _ in
            expectation.fulfill()
        }

        localeManager.clearLocale()

        await fulfillment(of: [expectation], timeout: 10.0)
    }

    @Test
    func testNotificationWhenAutoUpdateChanges() async {
        let localeManager = makeLocaleManager()
        let expectation = AirshipTestExpectation(description: "update called")
        self.notificationCenter.addObserver(
            forName: AirshipNotifications.LocaleUpdated.name
        ) { _ in
            expectation.fulfill()
        }

        self.notificationCenter.post(name: NSLocale.currentLocaleDidChangeNotification)

        await fulfillment(of: [expectation], timeout: 10.0)
        _ = localeManager
    }

}
