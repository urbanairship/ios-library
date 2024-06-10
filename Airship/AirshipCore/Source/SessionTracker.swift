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

    // Time to wait for the initial app init event when we start tracking
    // the session. We wait to generate an app init event for either a foreground,
    // background, or notification response so we can capture the push info for
    // conversion tracking
    private static let appInitWaitTime: TimeInterval = 1.0

    private let eventsContinuation: AsyncStream<SessionEvent>.Continuation
    public let events: AsyncStream<SessionEvent>

    private let date: AirshipDateProtocol
    private let taskSleeper: AirshipTaskSleeper
    private let isForeground: AirshipMainActorValue<Bool?> = AirshipMainActorValue(nil)
    private let initialized: AirshipMainActorValue<Bool> = AirshipMainActorValue(false)
    private let _sessionState: AirshipAtomicValue<SessionState>
    private let appStateTracker: AppStateTrackerProtocol
    private let sessionStateFactory: @Sendable () -> SessionState

    nonisolated var sessionState: SessionState {
        return _sessionState.value
    }

    @MainActor
    init(
        date: AirshipDateProtocol = AirshipDate.shared,
        taskSleeper: AirshipTaskSleeper = .shared,
        notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter.shared,
        appStateTracker: AppStateTrackerProtocol? = nil,
        sessionStateFactory: @Sendable @escaping () -> SessionState = { SessionState() }
    ) {
        self.date = date
        self.taskSleeper = taskSleeper
        self.appStateTracker = appStateTracker ?? AppStateTracker.shared
        (self.events, self.eventsContinuation) = AsyncStream<SessionEvent>.airshipMakeStreamWithContinuation()
        self.sessionStateFactory = sessionStateFactory
        self._sessionState = AirshipAtomicValue(sessionStateFactory())

        notificationCenter.addObserver(
            self,
            selector: #selector(didBecomeActiveNotification),
            name: AppStateTracker.didBecomeActiveNotification,
            object: nil
        )

        notificationCenter.addObserver(
            self,
            selector: #selector(didEnterBackgroundNotification),
            name: AppStateTracker.didEnterBackgroundNotification,
            object: nil
        )
    }

    @MainActor
    func launchedFromPush(sendID: String?, metadata: String?) {
        AirshipLogger.debug("Launched from push")

        self._sessionState.update { state in
            var state = state
            state.conversionMetadata = metadata
            state.conversionSendID = sendID
            return state
        }
        self.ensureInit(isForeground: true) {
            AirshipLogger.debug("App init - launched from push")
        }
    }

    @MainActor
    func airshipReady() {
        let date = self.date.now
        Task { @MainActor in
            try await self.taskSleeper.sleep(timeInterval: SessionTracker.appInitWaitTime)
            let isForeground = self.appStateTracker.state != .background
            self.ensureInit(isForeground: isForeground, date: date) {
                AirshipLogger.debug("App init - AirshipReady")
            }
        }
    }

    @MainActor
    private func ensureInit(isForeground: Bool, date: Date? = nil, onInit: () -> Void) {
        guard self.initialized.value else {
            self.initialized.set(true)
            self.isForeground.set(isForeground)
            self.addEvent(isForeground ? .foregroundInit : .backgroundInit, date: date)
            onInit()
            return
        }
    }

    @MainActor
    private func addEvent(_ type: SessionEvent.SessionEventType, date: Date? = nil) {
        AirshipLogger.debug("Added session event \(type) state: \(self.sessionState)")

        self.eventsContinuation.yield(
            SessionEvent(type: type, date: date ?? self.date.now, sessionState: self.sessionState)
        )
    }

    @objc
    @MainActor
    private func didBecomeActiveNotification() {
        AirshipLogger.debug("Application did become active.")

        // Ensure the app init event
        ensureInit(isForeground: true) {
            AirshipLogger.debug("App init - foreground")
        }

        // Background -> foreground
        if isForeground.value == false {
            isForeground.set(true)
            self._sessionState.update { [sessionStateFactory] old in
                var session = sessionStateFactory()
                session.conversionMetadata = old.conversionMetadata
                session.conversionSendID = old.conversionSendID
                return session
            }
            addEvent(.foreground)
        }
    }

    @objc
    @MainActor
    private func didEnterBackgroundNotification() {
        AirshipLogger.debug("Application entered background")

        // Ensure the app init event
        ensureInit(isForeground: false) {
            AirshipLogger.debug("App init - background")
        }

        // Foreground -> background
        if isForeground.value == true {
            isForeground.set(false)
            addEvent(.background)

            self._sessionState.value = self.sessionStateFactory()
        }
    }
}
