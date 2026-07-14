/* Copyright Airship and Contributors */

import Testing

@testable import AirshipAutomation

@MainActor
struct DisplayActivityTrackerTest {

    private let tracker = DisplayActivityTracker()

    @Test
    func testNotDisplayingByDefault() {
        #expect(!tracker.isDisplaying)
    }

    @Test
    func testTracksDisplays() {
        tracker.messageWillDisplay()
        #expect(tracker.isDisplaying)

        tracker.messageWillDisplay()
        tracker.messageFinishedDisplaying()
        #expect(tracker.isDisplaying)

        tracker.messageFinishedDisplaying()
        #expect(!tracker.isDisplaying)
    }

    @Test
    func testFinishWithoutDisplayDoesNotGoNegative() {
        tracker.messageFinishedDisplaying()
        #expect(!tracker.isDisplaying)

        tracker.messageWillDisplay()
        #expect(tracker.isDisplaying)

        tracker.messageFinishedDisplaying()
        #expect(!tracker.isDisplaying)
    }

    @Test
    func testUpdatesYieldCurrentValue() async {
        tracker.messageWillDisplay()

        var iterator = tracker.activeCountUpdates.makeAsyncIterator()
        let first = await iterator.next()
        #expect(first == 1)
    }

    @Test
    func testUpdatesStreamsChanges() async {
        tracker.messageWillDisplay()

        var iterator = tracker.activeCountUpdates.makeAsyncIterator()
        let first = await iterator.next()
        #expect(first == 1)

        tracker.messageWillDisplay()
        let second = await iterator.next()
        #expect(second == 2)

        tracker.messageFinishedDisplaying()
        let third = await iterator.next()
        #expect(third == 1)

        tracker.messageFinishedDisplaying()
        let fourth = await iterator.next()
        #expect(fourth == 0)
    }
}
