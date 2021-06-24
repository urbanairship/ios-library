/* Copyright Airship and Contributors */

@objc
public class UAUIKitStateTrackerAdapter: NSObject, UAAppStateTrackerAdapter {

    @objc
    public weak var stateTrackerDelegate: UAAppStateTrackerDelegate?

    private var notificationCenter: NotificationCenter
    private var dispatcher: UADispatcher

    @objc
    public var state: UAApplicationState {
        get {
            var result: UAApplicationState = .background
            dispatcher.doSync({
                switch UIApplication.shared.applicationState {
                case .active:
                    result = .active
                case .inactive:
                    result = .inactive
                case .background:
                    result = .background
                @unknown default:
                    break
                }
            })
            return result
        }
    }

    @objc
    public init(notificationCenter: NotificationCenter, dispatcher: UADispatcher) {
        self.notificationCenter = notificationCenter
        self.dispatcher = dispatcher
        super.init()
        observeStateEvents()
    }

    convenience override init() {
        self.init(notificationCenter: NotificationCenter.default, dispatcher: UADispatcher.main)
    }

    func observeStateEvents() {
        // active
        notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name:UIApplication.didBecomeActiveNotification,
            object: nil)

        // inactive
        notificationCenter.addObserver(
            self,
            selector: #selector(applicationWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil)

        // foreground
        notificationCenter.addObserver(
            self,
            selector: #selector(applicationWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil)

        // background
        notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil)


        notificationCenter.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil)
    }

    @objc
    func applicationDidBecomeActive() {
        stateTrackerDelegate?.applicationDidBecomeActive()
    }

    @objc
    func applicationWillEnterForeground() {
        stateTrackerDelegate?.applicationWillEnterForeground()
    }

    @objc
    func applicationDidEnterBackground() {
        stateTrackerDelegate?.applicationDidEnterBackground()
    }

    @objc
    func applicationWillTerminate() {
        stateTrackerDelegate?.applicationWillTerminate()
    }

    @objc
    func applicationWillResignActive() {
        stateTrackerDelegate?.applicationWillResignActive()
    }
}
