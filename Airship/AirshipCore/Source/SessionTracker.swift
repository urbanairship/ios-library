/* Copyright Airship and Contributors */

import Foundation

protocol SessionTrackerProtocol: Sendable {
    var sessionState: SessionState { get }
    var events: AsyncStream<SessionEvent> { get }

    @MainActor
    func airshipReady()

    @MainActor
    func launchedFromPush(sendID: String?, metadata: String?)
}


final class SessionTracker: SessionTrackerProtocol {

    // Time to wait for the initila app init event when we start tracking
    // the session. We wait to generate an app init event for either a foreground,
    // background, or notification response so we can capture the push info for
    // conversion tracking
    private static let appInitWaitTime: TimeInterval = 1.0

    private let eventsContinuation: AsyncStream<SessionEvent>.Continuation
    public let events: AsyncStream<SessionEvent>

    private let date: AirshipDateProtocol
    private let taskSleeper: AirshipTaskSleeper
    private let appInitEventCreated: AirshipMainActorWrapper<Bool> = AirshipMainActorWrapper(false)
    private let _sessionState: Atomic<SessionState> = Atomic(SessionState())

    var sessionState: SessionState {
        return _sessionState.value
    }

    init(
        date: AirshipDateProtocol = AirshipDate.shared,
        taskSleeper: AirshipTaskSleeper = .shared,
        notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter.shared
    ) {
        self.date = date
        self.taskSleeper = taskSleeper
        (self.events, self.eventsContinuation) = AsyncStream<SessionEvent>.makeStreamWithContinuation()

        notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidTransitionToForeground),
            name: AppStateTracker.didTransitionToForeground,
            object: nil
        )

        notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: AppStateTracker.didEnterBackgroundNotification,
            object: nil
        )

    }

    @MainActor
    func launchedFromPush(sendID: String?, metadata: String?) {
        self._sessionState.update { state in
            var state = state
            state.conversionMetadata = metadata
            state.conversionSendID = sendID
            return state
        }
        self.ensureInit {
            AirshipLogger.debug("App init - launched from push")
        }
    }

    @MainActor
    func airshipReady() {
        let date = self.date.now
        Task { @MainActor in
            try await self.taskSleeper.sleep(timeInterval: SessionTracker.appInitWaitTime)
            self.ensureInit(date: date) {
                AirshipLogger.debug("App init - AirshipReady")
            }
        }
    }

    @MainActor
    private func ensureInit(date: Date? = nil, onInit: () -> Void) {
        if !self.appInitEventCreated.value {
            self.addEvent(.appInit, date: date)
            onInit()
            self.appInitEventCreated.value = true
        }
    }

    private func startSession() {
        self._sessionState.value = SessionState()
    }

    private func addEvent(_ type: SessionEvent.EventType, date: Date? = nil) {
        self.eventsContinuation.yield(
            SessionEvent(type: type, date: date ?? self.date.now)
        )
    }

    @objc
    @MainActor
    private func applicationDidTransitionToForeground() {
        AirshipLogger.debug("Application did enter foreground.")

        // If the app is transitioning to foreground for the first time, ensure an app init event
        guard appInitEventCreated.value else {
            ensureInit {
                AirshipLogger.debug("App init - foreground")
            }
            return
        }

        // Otherwise start a new session and emit a foreground event.
        startSession()

        // Add app_foreground event
        self.addEvent(.foreground)
    }

    @objc
    @MainActor
    private func applicationDidEnterBackground() {
        AirshipLogger.debug("Application did enter background.")

        // Ensure an app init event
        ensureInit {
            AirshipLogger.debug("App init - background")
        }

        // Add app_background event
        self.addEvent(.background)

        startSession()
    }
}
