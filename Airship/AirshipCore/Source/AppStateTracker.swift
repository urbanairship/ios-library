/* Copyright Airship and Contributors */

import Foundation
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
}

/// NOTE: For internal use only. :nodoc:
@objc(UAAppStateTracker)
public final class AppStateTracker: NSObject, AppStateTrackerProtocol, @unchecked Sendable {

    @objc
    public static let didBecomeActiveNotification = NSNotification.Name(
        "com.urbanairship.application_did_become_active"
    )

    @objc
    public static let willEnterForegroundNotification = NSNotification.Name(
        "com.urbanairship.application_will_enter_foreground"
    )

    @objc
    public static let didEnterBackgroundNotification = NSNotification.Name(
        "com.urbanairship.application_did_enter_background"
    )

    @objc
    public static let willResignActiveNotification = NSNotification.Name(
        "com.urbanairship.application_will_resign_active"
    )

    @objc
    public static let willTerminateNotification = NSNotification.Name(
        "com.urbanairship.application_will_terminate"
    )

    @objc
    public static let didTransitionToBackground = NSNotification.Name(
        "com.urbanairship.application_did_transition_to_background"
    )

    @objc
    public static let didTransitionToForeground = NSNotification.Name(
        "com.urbanairship.application_did_transition_to_foreground"
    )

    @objc
    @MainActor
    public static let shared: AppStateTracker = AppStateTracker()

    private let notificationCenter: NotificationCenter
    private let adapter: AppStateTrackerAdapter

    @MainActor
    private var isForegrounded: Bool? = nil
    
    @objc(isForgrounded)
    @MainActor
    public var _isForegrounded: Bool {
        ensureForegroundSet()
        return isForegrounded == true
    }

    @objc
    @MainActor
    public var state: ApplicationState {
        return adapter.state
    }

    @MainActor
    init(
        adapter: AppStateTrackerAdapter = DefaultAppStateTrackerAdapter(),
        notificationCenter: NotificationCenter = NotificationCenter.default
    ) {
        self.adapter = adapter
        self.notificationCenter = notificationCenter
        super.init()

        Task { @MainActor in
            self.ensureForegroundSet()
        }
        
        self.adapter.watchAppLifeCycleEvents { event in
            self.ensureForegroundSet()
            
            switch(event) {
            case .didBecomeActive:
                self.postNotificaition(name: AppStateTracker.didBecomeActiveNotification)
                if self.isForegrounded == false {
                    self.isForegrounded = true
                    self.postNotificaition(name: AppStateTracker.didTransitionToForeground)
                }
                
            case .willResignActive:
                self.postNotificaition(name: AppStateTracker.willResignActiveNotification)
                
            case .willEnterForeground:
                self.postNotificaition(name: AppStateTracker.willEnterForegroundNotification)
                
            case .didEnterBackground:
                self.postNotificaition(name: AppStateTracker.didEnterBackgroundNotification)
                if self.isForegrounded == true {
                    self.isForegrounded = false
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
        if isForegrounded == nil {
            isForegrounded = self.state == .active
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
}


