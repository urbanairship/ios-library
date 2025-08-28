/* Copyright Airship and Contributors */


import Combine

/// NOTE: For internal use only. :nodoc:
public protocol AppStateTrackerProtocol: Sendable {
    /**
     * Current application state.
     */
    @MainActor
    var state: ApplicationState { get }

    /**
     * Waits for active
     */
    func waitForActive() async
    
    /**
     * State updates
     */
    @MainActor
    var stateUpdates: AsyncStream<ApplicationState> { get }
}

/// NOTE: For internal use only. :nodoc:
public final class AppStateTracker: AppStateTrackerProtocol, Sendable {


    public static let didBecomeActiveNotification = NSNotification.Name(
        "com.urbanairship.application_did_become_active"
    )

    public static let willEnterForegroundNotification = NSNotification.Name(
        "com.urbanairship.application_will_enter_foreground"
    )

    public static let didEnterBackgroundNotification = NSNotification.Name(
        "com.urbanairship.application_did_enter_background"
    )

    public static let willResignActiveNotification = NSNotification.Name(
        "com.urbanairship.application_will_resign_active"
    )

    public static let willTerminateNotification = NSNotification.Name(
        "com.urbanairship.application_will_terminate"
    )

    public static let didTransitionToBackground = NSNotification.Name(
        "com.urbanairship.application_did_transition_to_background"
    )

    public static let didTransitionToForeground = NSNotification.Name(
        "com.urbanairship.application_did_transition_to_foreground"
    )

    @MainActor
    public static let shared: AppStateTracker = AppStateTracker()

    private let notificationCenter: NotificationCenter
    private let adapter: any AppStateTrackerAdapter
    private let stateValue: AirshipMainActorValue<ApplicationState>

    @MainActor
    private var _isForegrounded: Bool? = nil

    @MainActor
    public var isForegrounded: Bool {
        ensureForegroundSet()
        return _isForegrounded == true
    }

    @MainActor
    public var state: ApplicationState {
        return stateValue.value
    }

    @MainActor
    init(
        adapter: any AppStateTrackerAdapter = DefaultAppStateTrackerAdapter(),
        notificationCenter: NotificationCenter = NotificationCenter.default
    ) {
        self.adapter = adapter
        self.notificationCenter = notificationCenter
        self.stateValue = AirshipMainActorValue(adapter.state)

        Task { @MainActor in
            self.ensureForegroundSet()
        }
        
        self.adapter.watchAppLifeCycleEvents { event in
            self.ensureForegroundSet()

            if (self.stateValue.value != adapter.state) {
                self.stateValue.set(adapter.state)
            }

            switch(event) {
            case .didBecomeActive:
                self.postNotificaition(name: AppStateTracker.didBecomeActiveNotification)
                if self._isForegrounded == false {
                    self._isForegrounded = true
                    self.postNotificaition(name: AppStateTracker.didTransitionToForeground)
                }
                
            case .willResignActive:
                self.postNotificaition(name: AppStateTracker.willResignActiveNotification)
                
            case .willEnterForeground:
                self.postNotificaition(name: AppStateTracker.willEnterForegroundNotification)
                
            case .didEnterBackground:
                self.postNotificaition(name: AppStateTracker.didEnterBackgroundNotification)
                if self._isForegrounded == true {
                    self._isForegrounded = false
                    self.postNotificaition(name: AppStateTracker.didTransitionToBackground)
                }
                
            case .willTerminate:
                self.postNotificaition(name: AppStateTracker.willTerminateNotification)
            }
        }
    }
    
    private func postNotificaition(name: Notification.Name) {
        notificationCenter.post(
            name: name,
            object: nil
        )
    }
    
    @MainActor
    private func ensureForegroundSet() {
        if _isForegrounded == nil {
            _isForegrounded = self.state == .active
        }
    }

    @MainActor
    public func waitForActive() async {
        var subscription: AnyCancellable?
        await withCheckedContinuation { continuation in
            subscription = self.notificationCenter.publisher(
                for: AppStateTracker.didBecomeActiveNotification
            )
            .first()
            .sink { _ in
                continuation.resume()
            }
        }

        subscription?.cancel()
    }

    @MainActor
    public var stateUpdates: AsyncStream<ApplicationState> {
        self.stateValue.updates
    }

}


