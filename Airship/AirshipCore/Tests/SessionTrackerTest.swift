/* Copyright Airship and Contributors */

import Testing
@testable
@_spi(AirshipInternal) import AirshipCore
@_spi(AirshipInternal) import AirshipBasement
import Foundation

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct SessionTrackerTest {

    private let taskSleeper: TestTaskSleeper = TestTaskSleeper()
    private let notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter()
    private let date: UATestDate = UATestDate(offset: 0, dateOverride: Date())
    private let appStateTracker: TestAppStateTracker = TestAppStateTracker()

    let tracker: SessionTracker

    let sessionCount = AirshipAtomicValue<Int>(1)

    init() {
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

    @Test
    func testDidBecomeActiveAppInit() async throws {
        Task { @MainActor [notificationCenter] in
            notificationCenter.post(
                name: AppStateTracker.didBecomeActiveNotification,
                object: nil
            )
        }

        var asyncIterator  = self.tracker.events.makeAsyncIterator()
        let event = await asyncIterator.next()!
        #expect(.foregroundInit == event.type)
        #expect(self.date.now == event.date)
    }

    @Test
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

        #expect(self.tracker.sessionState.sessionID == "1")
    }

    @Test
    func testLaunchFromPushEmitsAppInit() async throws {
        self.tracker.launchedFromPush(sendID: "some sendID", metadata: "some metadata")

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

        #expect(self.tracker.sessionState == expectedSessionState)
    }

    @Test
    func testAirshipReadyEmitsAppInitActiveState() async throws {
        self.appStateTracker.currentState = .active

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

        let sleeps = await self.taskSleeper.sleeps
        #expect([1.0] == sleeps)
        #expect(self.tracker.sessionState == expectedSessionState)
    }

    @Test
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

        let sleeps = await self.taskSleeper.sleeps
        #expect([1.0] == sleeps)
        #expect(self.tracker.sessionState == expectedSessionState)
    }

    @Test
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

        let sleeps = await self.taskSleeper.sleeps
        #expect([1.0] == sleeps)
        #expect(self.tracker.sessionState == expectedSessionState)
    }

    @Test
    func testLaunchFromPushAppBackgroundState() async throws {
        self.appStateTracker.currentState = .background

        let expectedSessionState = SessionState(
            sessionID: "1",
            conversionSendID: "some sendID",
            conversionMetadata: "some metadata"
        )

        Task {  @MainActor [tracker, notificationCenter] in
            // launch from push
            tracker.launchedFromPush(sendID: "some sendID", metadata: "some metadata")

            // This would normally be called with a delay, so calling it after
            tracker.airshipReady()

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

        #expect(self.tracker.sessionState == expectedSessionState)
    }

    @Test
    func testLaunchFromPushAppInActiveState() async throws {
        self.appStateTracker.currentState = .inactive

        let expectedSessionState = SessionState(
            sessionID: "1",
            conversionSendID: "some sendID",
            conversionMetadata: "some metadata"
        )

        Task { @MainActor [tracker, notificationCenter] in
            // launch from push
            tracker.launchedFromPush(sendID: "some sendID", metadata: "some metadata")

            // This would normally be called with a delay, so calling it after
            tracker.airshipReady()

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

        #expect(self.tracker.sessionState == expectedSessionState)
    }

    @Test
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
        #expect(self.tracker.sessionState == SessionState(sessionID: "3"))

    }

    @Test
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
        #expect(self.tracker.sessionState == SessionState(sessionID: "2"))
    }

    @Test
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
        #expect(self.tracker.sessionState == SessionState(sessionID: "2"))
    }

    @Test
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
            tracker.launchedFromPush(sendID: "some sendID", metadata: "some metadata")

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
        #expect(self.tracker.sessionState == expectedSessionState)
    }

    @Test
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
        #expect(self.tracker.sessionState == SessionState(sessionID: "3"))
    }

    private func ensureEvents(_ events: [SessionEvent], sourceLocation: SourceLocation = #_sourceLocation) async {
        let verifyTask = Task { [tracker] in
            var asyncIterator = tracker.events.makeAsyncIterator()
            for expected in events {
                if Task.isCancelled {
                    break
                }

                let next = await asyncIterator.next()
                #expect(expected == next, sourceLocation: sourceLocation)
            }
        }

        let timeoutTask = Task {
            try? await DefaultAirshipTaskSleeper.shared.sleep(timeInterval:2.0)
            if Task.isCancelled == false {
                Issue.record("Failed to get events", sourceLocation: sourceLocation)
                verifyTask.cancel()
            }
        }

        await verifyTask.value
        timeoutTask.cancel()
    }
}
