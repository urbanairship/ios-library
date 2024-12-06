/* Copyright Airship and Contributors */

import XCTest
@testable
import AirshipCore

final class AirshipAnalyticFeedTest: XCTestCase {
    private let dataStore: PreferenceDataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private var privacyManager: AirshipPrivacyManager!

    override func setUp() async throws {
        self.privacyManager = await AirshipPrivacyManager(
            dataStore: dataStore,
            config: .testConfig(),
            defaultEnabledFeatures: .all
        )
    }

    func testFeed() async throws {
        let feed = makeFeed()
        var updates = await feed.updates.makeAsyncIterator()

        let result = await feed.notifyEvent(.screen(screen: "foo"))
        XCTAssertTrue(result)

        let next = await updates.next()
        XCTAssertEqual(next, .screen(screen: "foo"))
    }

    func testFeedAnalyticsDisabled() async throws {
        let feed = makeFeed()
        privacyManager.disableFeatures(.analytics)
        var updates = await feed.updates.makeAsyncIterator()

        var result = await feed.notifyEvent(.screen(screen: "foo"))
        XCTAssertFalse(result)

        privacyManager.enableFeatures(.analytics)
        result = await feed.notifyEvent(.screen(screen: "bar"))
        XCTAssertTrue(result)

        let next = await updates.next()
        XCTAssertEqual(next, .screen(screen: "bar"))
    }

    func testFeedDisabled() async throws {
        let feed = makeFeed(enabled: false)
        let result = await feed.notifyEvent(.screen(screen: "foo"))
        XCTAssertFalse(result)
    }

    private func makeFeed(enabled: Bool = true) -> AirshipAnalyticsFeed  {
        return AirshipAnalyticsFeed(privacyManager: privacyManager, isAnalyticsEnabled: enabled)
    }
}
