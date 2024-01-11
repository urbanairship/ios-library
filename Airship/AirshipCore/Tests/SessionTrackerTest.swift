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

    var sessionCount = Atomic<Int>(1)

    override func setUpWithError() throws {
        self.tracker = SessionTracker(
            date: date,
            taskSleeper: taskSleeper,
            appStateTracker: appStateTracker,
            sessionStateFactory: { [sessionCount] in
                let state = SessionState(sessionID: "\(sessionCount.value)")
                sessionCount.value = sessionCount.value + 1
                return state
            }
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
            SessionEvent(
                type: .backgroundInit,
                date: self.date.now,
                sessionState: SessionState(sessionID: "1")
            ),
        ])

        XCTAssertEqual(self.tracker.sessionState.sessionID, "1")
    }

    func testLaunchFromPushEmitsAppInit() async throws {
        await self.tracker.launchedFromPush(sendID: "some sendID", metadata: "some metadata")

        let expectedSessionState = SessionState(
            sessionID: "1",
            conversionSendID: "some sendID",
            conversionMetadata: "some metadata"
        )

        await ensureEvents([
            SessionEvent(
                type: .foregroundInit,
                date: self.date.now,
                sessionState: expectedSessionState
            )
        ])

        XCTAssertEqual(self.tracker.sessionState, expectedSessionState)
    }

    @MainActor
    func testAirshipReadyEmitsAppInitActiveState() async throws {
        self.appStateTracker.currentState = .active

        let expectedSessionState = SessionState(
            sessionID: "1"
        )

        await self.tracker.airshipReady()
        await ensureEvents([
            SessionEvent(
                type: .foregroundInit,
                date: self.date.now,
                sessionState: expectedSessionState
            )
        ])

        XCTAssertEqual([1.0], self.taskSleeper.sleeps)
        XCTAssertEqual(self.tracker.sessionState, expectedSessionState)
    }

    @MainActor
    func testAirshipReadyEmitsAppInitInActiveState() async throws {
        self.appStateTracker.currentState = .inactive

        let expectedSessionState = SessionState(
            sessionID: "1"
        )

        self.tracker.airshipReady()
        await ensureEvents([
            SessionEvent(
                type: .foregroundInit,
                date: self.date.now,
                sessionState: expectedSessionState
            )
        ])

        XCTAssertEqual([1.0], self.taskSleeper.sleeps)
        XCTAssertEqual(self.tracker.sessionState, expectedSessionState)
    }

    @MainActor
    func testAirshipReadyEmitsAppBackgroundState() async throws {
        self.appStateTracker.currentState = .background

        let expectedSessionState = SessionState(
            sessionID: "1"
        )

        self.tracker.airshipReady()
        await ensureEvents([
            SessionEvent(
                type: .backgroundInit,
                date: self.date.now,
                sessionState: expectedSessionState
            )
        ])

        XCTAssertEqual([1.0], self.taskSleeper.sleeps)
        XCTAssertEqual(self.tracker.sessionState, expectedSessionState)
    }

    @MainActor
    func testLaunchFromPushAppBackgroundState() async throws {
        self.appStateTracker.currentState = .background

        let expectedSessionState = SessionState(
            sessionID: "1",
            conversionSendID: "some sendID",
            conversionMetadata: "some metadata"
        )

        Task {  @MainActor [tracker, notificationCenter] in
            // launch from push
            tracker?.launchedFromPush(sendID: "some sendID", metadata: "some metadata")

            // This would normally be called with a delay, so calling it after
            tracker?.airshipReady()

            // Foreground
            notificationCenter.post(
                name: AppStateTracker.didBecomeActiveNotification,
                object: nil
            )
        }

        await ensureEvents([
            SessionEvent(
                type: .foregroundInit,
                date: self.date.now,
                sessionState: expectedSessionState
            )
        ])

        XCTAssertEqual(self.tracker.sessionState, expectedSessionState)
    }

    @MainActor
    func testLaunchFromPushAppInActiveState() async throws {
        self.appStateTracker.currentState = .inactive

        let expectedSessionState = SessionState(
            sessionID: "1",
            conversionSendID: "some sendID",
            conversionMetadata: "some metadata"
        )

        Task { @MainActor [tracker, notificationCenter] in
            // launch from push
            tracker?.launchedFromPush(sendID: "some sendID", metadata: "some metadata")

            // This would normally be called with a delay, so calling it after
            tracker?.airshipReady()

            // Foreground
            notificationCenter.post(
                name: AppStateTracker.didBecomeActiveNotification,
                object: nil
            )
        }

        await ensureEvents([
            SessionEvent(
                type: .foregroundInit,
                date: self.date.now,
                sessionState: expectedSessionState
            )
        ])

        XCTAssertEqual(self.tracker.sessionState, expectedSessionState)
    }

    @MainActor
    func testLaunchAppBackgroundState() async throws {
        self.appStateTracker.currentState = .background

        // App init
        self.tracker.airshipReady()

        await ensureEvents([
            SessionEvent(
                type: .backgroundInit,
                date: self.date.now,
                sessionState: SessionState(
                    sessionID: "1"
                )
            )
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

        let expectedSessionState = SessionState(
            sessionID: "2"
        )

        await ensureEvents([
            SessionEvent(
                type: .foreground,
                date: self.date.now,
                sessionState: expectedSessionState
            ),
            SessionEvent(
                type: .background,
                date: self.date.now,
                sessionState: expectedSessionState
            )
        ])

        // Background should reset state
        XCTAssertEqual(self.tracker.sessionState, SessionState(sessionID: "3"))

    }

    @MainActor
    func testLaunchAppInactiveState() async throws {
        self.appStateTracker.currentState = .inactive

        // App init
        self.tracker.airshipReady()

        await ensureEvents([
            SessionEvent(
                type: .foregroundInit,
                date: self.date.now,
                sessionState: SessionState(
                    sessionID: "1"
                )
            )
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
            SessionEvent(
                type: .background,
                date: self.date.now,
                sessionState: SessionState(
                    sessionID: "1"
                )
            )
        ])

        // Background should reset state
        XCTAssertEqual(self.tracker.sessionState, SessionState(sessionID: "2"))
    }

    @MainActor
    func testLaunchAppActiveState() async throws {
        appStateTracker.currentState = .active

        // App init
        self.tracker.airshipReady()

        await ensureEvents([
            SessionEvent(
                type: .foregroundInit,
                date: self.date.now,
                sessionState: SessionState(
                    sessionID: "1"
                )
            )
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
            SessionEvent(
                type: .background,
                date: self.date.now,
                sessionState: SessionState(
                    sessionID: "1"
                )
            )
        ])

        // Background should reset state
        XCTAssertEqual(self.tracker.sessionState, SessionState(sessionID: "2"))
    }

    @MainActor
    func testLaunchContentAvailablePush() async throws {
        self.appStateTracker.currentState = .background

        // App init
        self.tracker.airshipReady()

        await ensureEvents([
            SessionEvent(
                type: .backgroundInit,
                date: self.date.now,
                sessionState: SessionState(
                    sessionID: "1"
                )
            )
        ])


        Task { @MainActor [tracker, notificationCenter] in
            // launch from push
            tracker?.launchedFromPush(sendID: "some sendID", metadata: "some metadata")

            // Foreground
            notificationCenter.post(
                name: AppStateTracker.didBecomeActiveNotification,
                object: nil
            )
        }

        let expectedSessionState = SessionState(
            sessionID: "2",
            conversionSendID: "some sendID",
            conversionMetadata: "some metadata"
        )

        await ensureEvents([
            SessionEvent(
                type: .foreground,
                date: self.date.now,
                sessionState: expectedSessionState
            )
        ])

        // Foreground should generate new session ID
        XCTAssertEqual(self.tracker.sessionState, expectedSessionState)
    }

    @MainActor
    func testBackgroundClearPush() async throws {
        self.appStateTracker.currentState = .background

        self.tracker.launchedFromPush(sendID: "some sendID", metadata: "some metadata")

        await ensureEvents([
            SessionEvent(
                type: .foregroundInit,
                date: self.date.now,
                sessionState: SessionState(
                    sessionID: "1",
                    conversionSendID: "some sendID",
                    conversionMetadata: "some metadata"
                )
            )
        ])


        Task { @MainActor [notificationCenter] in
            // Background
            notificationCenter.post(
                name: AppStateTracker.didEnterBackgroundNotification,
                object: nil
            )

            // Foreground
            notificationCenter.post(
                name: AppStateTracker.didBecomeActiveNotification,
                object: nil
            )
        }

        await ensureEvents([
            SessionEvent(
                type: .background,
                date: self.date.now,
                sessionState: SessionState(
                    sessionID: "1",
                    conversionSendID: "some sendID",
                    conversionMetadata: "some metadata"
                )
            ),
            SessionEvent(
                type: .foreground,
                date: self.date.now,
                sessionState: SessionState(
                    sessionID: "3"
                )
            )
        ])

        // Foreground should generate new session ID
        XCTAssertEqual(self.tracker.sessionState, SessionState(sessionID: "3"))
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
