/* Copyright Airship and Contributors */

import Foundation

@objc(UAAppStateTracker)
open class AppStateTracker: NSObject, AppStateTrackerDelegate, AppStateTrackerProtocol {
    
    @objc
    public static let didBecomeActiveNotification = NSNotification.Name("com.urbanairship.application_did_become_active")

    @objc
    public static let willEnterForegroundNotification = NSNotification.Name("com.urbanairship.application_will_enter_foreground")

    @objc
    public static let didEnterBackgroundNotification = NSNotification.Name("com.urbanairship.application_did_enter_background")

    @objc
    public static let willResignActiveNotification = NSNotification.Name("com.urbanairship.application_will_resign_active")

    @objc
    public static let willTerminateNotification = NSNotification.Name("com.urbanairship.application_will_terminate")

    @objc
    public static let didTransitionToBackground = NSNotification.Name("com.urbanairship.application_did_transition_to_background")

    @objc
    public static let didTransitionToForeground = NSNotification.Name("com.urbanairship.application_did_transition_to_foreground")

    @objc
    public static let shared: AppStateTracker = AppStateTracker()

    private var adapter: AppStateTrackerAdapter?
    private let notificationCenter: NotificationCenter
    private var isForegrounded: Bool

    @objc
    open var state: ApplicationState {
        get {
            return adapter?.state ?? .background
        }
    }

    @objc
    public init(notificationCenter: NotificationCenter, adapter: AppStateTrackerAdapter?) {
        self.notificationCenter = notificationCenter
        self.adapter = adapter
        self.isForegrounded = adapter?.state == .active
        super.init()
        self.adapter?.stateTrackerDelegate = self
    }

    public override convenience init() {
#if !os(watchOS)
        self.init(notificationCenter: NotificationCenter.default, adapter: UIKitStateTrackerAdapter())
#else
        self.init(notificationCenter: NotificationCenter.default, adapter: WKStateTrackerAdapter())
#endif
    }

    @objc
    public func applicationDidBecomeActive() {
        notificationCenter.post(name: AppStateTracker.didBecomeActiveNotification, object: nil)

        if !isForegrounded {
            isForegrounded = true
            notificationCenter.post(name: AppStateTracker.didTransitionToForeground, object: nil)
        }
    }

    @objc
    public func applicationWillEnterForeground() {
        notificationCenter.post(name: AppStateTracker.willEnterForegroundNotification, object: nil)
    }

    @objc
    public func applicationDidEnterBackground() {
        notificationCenter.post(name: AppStateTracker.didEnterBackgroundNotification, object: nil)

        if isForegrounded {
            isForegrounded = false
            notificationCenter.post(name: AppStateTracker.didTransitionToBackground, object: nil)
        }
    }

    @objc
    public func applicationWillResignActive() {
        notificationCenter.post(name: AppStateTracker.willResignActiveNotification, object: nil)
    }

    @objc
    public func applicationWillTerminate() {
        notificationCenter.post(name: AppStateTracker.willTerminateNotification, object: nil)
    }
}

@objc
public protocol AppStateTrackerProtocol {
    var state: ApplicationState { get }
}
