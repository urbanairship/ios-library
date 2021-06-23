/* Copyright Airship and Contributors */


@objc
open class UAAppStateTracker: NSObject, UAAppStateTrackerDelegate {

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
    public static let shared: UAAppStateTracker = UAAppStateTracker()

    private var adapter: UAAppStateTrackerAdapter?
    private let notificationCenter: NotificationCenter
    private var isForegrounded: Bool

    @objc
    open var state: UAApplicationState {
        get {
            return adapter?.state ?? .background
        }
    }

    @objc
    public init(notificationCenter: NotificationCenter, adapter: UAAppStateTrackerAdapter?) {
        self.notificationCenter = notificationCenter
        self.adapter = adapter
        self.isForegrounded = adapter?.state == .active
        super.init()
        self.adapter?.stateTrackerDelegate = self
    }

    public override convenience init() {
        self.init(notificationCenter: NotificationCenter.default, adapter: UAUIKitStateTrackerAdapter())
    }

    @objc
    public func applicationDidBecomeActive() {
        notificationCenter.post(name: UAAppStateTracker.didBecomeActiveNotification, object: nil)

        if !isForegrounded {
            isForegrounded = true
            notificationCenter.post(name: UAAppStateTracker.didTransitionToForeground, object: nil)
        }
    }

    @objc
    public func applicationWillEnterForeground() {
        notificationCenter.post(name: UAAppStateTracker.willEnterForegroundNotification, object: nil)
    }

    @objc
    public func applicationDidEnterBackground() {
        notificationCenter.post(name: UAAppStateTracker.didEnterBackgroundNotification, object: nil)

        if isForegrounded {
            isForegrounded = false
            notificationCenter.post(name: UAAppStateTracker.didTransitionToBackground, object: nil)
        }
    }

    @objc
    public func applicationWillResignActive() {
        notificationCenter.post(name: UAAppStateTracker.willResignActiveNotification, object: nil)
    }

    @objc
    public func applicationWillTerminate() {
        notificationCenter.post(name: UAAppStateTracker.willTerminateNotification, object: nil)
    }
}
