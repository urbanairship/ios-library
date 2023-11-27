/* Copyright Airship and Contributors */

import XCTest
@testable
import AirshipCore

final class SessionTrackerTest: XCTestCase {

    private let taskSleeper: TestTaskSleeper = TestTaskSleeper()
    private let notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter()
    private let date: UATestDate = UATestDate(offset: 0, dateOverride: Date())
    private let appStateTracker: TestAppStateTracker = TestAppStateTracker()

    var tracker: SessionTracker!

    override func setUpWithError() throws {
        self.tracker = SessionTracker(
            date: date,
            taskSleeper: taskSleeper,
            appStateTracker: appStateTracker
        )
    }

    func testDidBecomeActiveAppInit() async throws {
        Task { @MainActor [notificationCenter] in
            notificationCenter.post(
                name: AppStateTracker.didBecomeActiveNotification,
                object: nil
            )
        }

        var asyncIterator  = self.tracker.events.makeAsyncIterator()
        let event = await asyncIterator.next()!
        XCTAssertEqual(.foregroundInit, event.type)
        XCTAssertEqual(self.date.now, event.date)
    }

    func testBackgroundBeforeForegroundEmitsAppInit() async throws {
        Task { @MainActor [notificationCenter] in
            notificationCenter.post(
                name: AppStateTracker.didEnterBackgroundNotification,
                object: nil
            )
        }

        await ensureEvents([
            SessionEvent(type: .backgroundInit, date: self.date.now),
        ])
    }

    func testLaunchFromPushEmitsAppInit() async throws {
        await self.tracker.launchedFromPush(sendID: "some sender", metadata: "some metadata")

        await ensureEvents([
            SessionEvent(type: .foregroundInit, date: self.date.now),
        ])
    }

    func testAirshipReadyEmitsAppInitActiveState() async throws {
        self.appStateTracker.currentState = .active

        await self.tracker.airshipReady()
        await ensureEvents([
            SessionEvent(type: .foregroundInit, date: self.date.now),
        ])
        XCTAssertEqual([1.0], self.taskSleeper.sleeps)
    }


    func testAirshipReadyEmitsAppInitInActiveState() async throws {
        self.appStateTracker.currentState = .inactive

        await self.tracker.airshipReady()
        await ensureEvents([
            SessionEvent(type: .foregroundInit, date: self.date.now),
        ])
        XCTAssertEqual([1.0], self.taskSleeper.sleeps)
    }

    func testAirshipReadyEmitsAppBackgroundState() async throws {
        self.appStateTracker.currentState = .background

        await self.tracker.airshipReady()
        await ensureEvents([
            SessionEvent(type: .backgroundInit, date: self.date.now),
        ])
        XCTAssertEqual([1.0], self.taskSleeper.sleeps)
    }

    func testLaunchFromPushAppBackgroundState() async throws {
        self.appStateTracker.currentState = .background
        Task {  @MainActor [tracker, notificationCenter] in
            // launch from push
            tracker?.launchedFromPush(sendID: "some sender", metadata: "some metadata")

            // This would normally be called with a delay, so calling it after
            tracker?.airshipReady()

            // Foreground
            notificationCenter.post(
                name: AppStateTracker.didBecomeActiveNotification,
                object: nil
            )

            // Background
            notificationCenter.post(
                name: AppStateTracker.didEnterBackgroundNotification,
                object: nil
            )
        }

        await ensureEvents([
            SessionEvent(type: .foregroundInit, date: self.date.now),
            SessionEvent(type: .background, date: self.date.now)
        ])
    }

    func testLaunchFromPushAppInActiveState() async throws {
        self.appStateTracker.currentState = .inactive
        Task { @MainActor [tracker, notificationCenter] in
            // launch from push
            tracker?.launchedFromPush(sendID: "some sender", metadata: "some metadata")

            // This would normally be called with a delay, so calling it after
            tracker?.airshipReady()

            // Foreground
            notificationCenter.post(
                name: AppStateTracker.didBecomeActiveNotification,
                object: nil
            )

            // Background
            notificationCenter.post(
                name: AppStateTracker.didEnterBackgroundNotification,
                object: nil
            )
        }

        await ensureEvents([
            SessionEvent(type: .foregroundInit, date: self.date.now),
            SessionEvent(type: .background, date: self.date.now)
        ])
    }

    func testLaunchAppBackgroundState() async throws {
        self.appStateTracker.currentState = .background

        // App init
        await self.tracker.airshipReady()

        await ensureEvents([
            SessionEvent(type: .backgroundInit, date: self.date.now)
        ])

        Task { @MainActor [notificationCenter] in
            // Foreground
            notificationCenter.post(
                name: AppStateTracker.didBecomeActiveNotification,
                object: nil
            )

            // Background
            notificationCenter.post(
                name: AppStateTracker.didEnterBackgroundNotification,
                object: nil
            )
        }

        await ensureEvents([
            SessionEvent(type: .foreground, date: self.date.now),
            SessionEvent(type: .background, date: self.date.now)
        ])
    }

    func testLaunchAppInactiveState() async throws {
        self.appStateTracker.currentState = .inactive

        // App init
        await self.tracker.airshipReady()

        await ensureEvents([
            SessionEvent(type: .foregroundInit, date: self.date.now)
        ])

        Task { @MainActor [notificationCenter] in
            // Foreground
            notificationCenter.post(
                name: AppStateTracker.didBecomeActiveNotification,
                object: nil
            )

            // Background
            notificationCenter.post(
                name: AppStateTracker.didEnterBackgroundNotification,
                object: nil
            )
        }

        await ensureEvents([
            SessionEvent(type: .background, date: self.date.now)
        ])
    }


    func testLaunchAppActiveState() async throws {
        self.appStateTracker.currentState = .active

        // App init
        await self.tracker.airshipReady()

        await ensureEvents([
            SessionEvent(type: .foregroundInit, date: self.date.now)
        ])

        Task { @MainActor [notificationCenter] in
            // Foreground
            notificationCenter.post(
                name: AppStateTracker.didBecomeActiveNotification,
                object: nil
            )

            // Background
            notificationCenter.post(
                name: AppStateTracker.didEnterBackgroundNotification,
                object: nil
            )
        }

        await ensureEvents([
            SessionEvent(type: .background, date: self.date.now)
        ])
    }

    private func ensureEvents(_ events: [SessionEvent], line: UInt = #line) async {
        let verifyTask = Task { [tracker] in
            var asyncIterator = tracker!.events.makeAsyncIterator()
            for expected in events {
                if Task.isCancelled {
                    break
                }

                let next = await asyncIterator.next()
                XCTAssertEqual(expected, next, line: line)
            }
        }

        let timeoutTask = Task {
            try? await DefaultAirshipTaskSleeper().sleep(timeInterval:2.0)
            if Task.isCancelled == false {
                XCTFail("Failed to get events", line: line)
                verifyTask.cancel()
            }
        }

        await verifyTask.value
        timeoutTask.cancel()
    }
}

fileprivate final class TestTaskSleeper : AirshipTaskSleeper, @unchecked Sendable {
    var sleeps : [TimeInterval] = []

    func sleep(timeInterval: TimeInterval) async throws {
        sleeps.append(timeInterval)
    }
}
