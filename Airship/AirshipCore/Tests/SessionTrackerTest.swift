/* Copyright Airship and Contributors */

import XCTest
@testable
import AirshipCore

final class SessionTrackerTest: XCTestCase {

    private let taskSleeper: TestTaskSleeper = TestTaskSleeper()
    private let notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter()
    private let date: UATestDate = UATestDate(offset: 0, dateOverride: Date())

    var tracker: SessionTracker!

    override func setUpWithError() throws {
        self.tracker = SessionTracker(date: date, taskSleeper: taskSleeper)
    }

    func testFirstTransitionToForegroundEmitsAppInit() async throws {
        self.notificationCenter.post(
            name: AppStateTracker.didTransitionToForeground,
            object: nil
        )

        self.notificationCenter.post(
            name: AppStateTracker.didTransitionToForeground,
            object: nil
        )

        var asyncIterator  = self.tracker.events.makeAsyncIterator()
        var event = await asyncIterator.next()!
        XCTAssertEqual(.appInit, event.type)
        XCTAssertEqual(self.date.now, event.date)

        event = await asyncIterator.next()!
        XCTAssertEqual(.foreground, event.type)
        XCTAssertEqual(self.date.now, event.date)
    }

    func testBackgroundBeforeForegroundEmitsAppInit() async throws {
        self.notificationCenter.post(
            name: AppStateTracker.didEnterBackgroundNotification,
            object: nil
        )

        var asyncIterator  = self.tracker.events.makeAsyncIterator()
        let event = await asyncIterator.next()!
        XCTAssertEqual(.appInit, event.type)
        XCTAssertEqual(self.date.now, event.date)
    }

    func testLaunchFromPushEmitsAppInit() async throws {
        await self.tracker.launchedFromPush(sendID: "some sender", metadata: "some metadata")

        var asyncIterator  = self.tracker.events.makeAsyncIterator()
        let event = await asyncIterator.next()!
        XCTAssertEqual(.appInit, event.type)
        XCTAssertEqual(self.date.now, event.date)
    }

    func testAirshipReadyEmitsAppInitWithDelay() async throws {
        await self.tracker.airshipReady()
        var asyncIterator  = self.tracker.events.makeAsyncIterator()
        let event = await asyncIterator.next()!
        XCTAssertEqual(.appInit, event.type)
        XCTAssertEqual(self.date.now, event.date)

        XCTAssertEqual([1.0], self.taskSleeper.sleeps)
    }

    @MainActor
    func testEvents() async throws {
        // App init
        self.tracker.airshipReady()

        // Background
        self.notificationCenter.post(
            name: AppStateTracker.didEnterBackgroundNotification,
            object: nil
        )
        // Foreground
        self.notificationCenter.post(
            name: AppStateTracker.didTransitionToForeground,
            object: nil
        )

        var asyncIterator  = self.tracker.events.makeAsyncIterator()
        var event = await asyncIterator.next()!
        XCTAssertEqual(.appInit, event.type)
        XCTAssertEqual(self.date.now, event.date)

        event = await asyncIterator.next()!
        XCTAssertEqual(.background, event.type)
        XCTAssertEqual(self.date.now, event.date)

        event = await asyncIterator.next()!
        XCTAssertEqual(.foreground, event.type)
        XCTAssertEqual(self.date.now, event.date)
    }
}

fileprivate final class TestTaskSleeper : AirshipTaskSleeper, @unchecked Sendable {
    var sleeps : [TimeInterval] = []

    func sleep(timeInterval: TimeInterval) async throws {
        sleeps.append(timeInterval)
    }
}
