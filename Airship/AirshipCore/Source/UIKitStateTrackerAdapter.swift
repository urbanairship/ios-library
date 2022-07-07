/* Copyright Airship and Contributors */

#if !os(watchOS)

@objc(UAUIKitStateTrackerAdapter)
@available(iOSApplicationExtension, unavailable)
public class UIKitStateTrackerAdapter: NSObject, AppStateTrackerAdapter {

    @objc
    public weak var stateTrackerDelegate: AppStateTrackerDelegate?

    private var notificationCenter: NotificationCenter
    private var dispatcher: UADispatcher

    @objc
    public var state: ApplicationState {
        get {
            var result: ApplicationState = .background
            dispatcher.doSync({
                let appState = UIApplication.shared.applicationState
                switch appState {
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
            name: UIApplication.didBecomeActiveNotification,
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

#endif
