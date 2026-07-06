/* Copyright Airship and Contributors */

import Testing
import Foundation
@testable
@_spi(AirshipInternal) import AirshipCore

@Suite(.timeLimit(.minutes(1)))
struct AirshipAnalyticFeedTest {
    private let dataStore: PreferenceDataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private let privacyManager: TestPrivacyManager

    init() {
        self.privacyManager = TestPrivacyManager(
            dataStore: dataStore,
            config: .testConfig(),
            defaultEnabledFeatures: .all
        )
    }

    @Test
    func testFeed() async throws {
        let feed = makeFeed()
        var updates = await feed.updates.makeAsyncIterator()

        let result = await feed.notifyEvent(.screen(screen: "foo"))
        #expect(result)

        let next = await updates.next()
        #expect(next == .screen(screen: "foo"))
    }

    @Test
    func testFeedAnalyticsDisabled() async throws {
        let feed = makeFeed()
        privacyManager.disableFeatures(.analytics)
        var updates = await feed.updates.makeAsyncIterator()

        var result = await feed.notifyEvent(.screen(screen: "foo"))
        #expect(!(result))

        privacyManager.enableFeatures(.analytics)
        result = await feed.notifyEvent(.screen(screen: "bar"))
        #expect(result)

        let next = await updates.next()
        #expect(next == .screen(screen: "bar"))
    }

    @Test
    func testFeedDisabled() async throws {
        let feed = makeFeed(enabled: false)
        let result = await feed.notifyEvent(.screen(screen: "foo"))
        #expect(!(result))
    }

    private func makeFeed(enabled: Bool = true) -> AirshipAnalyticsFeed  {
        return AirshipAnalyticsFeed(privacyManager: privacyManager, isAnalyticsEnabled: enabled)
    }
}
