/* Copyright Airship and Contributors */

#if os(watchOS)
import WatchKit

@objc(UAWKStateTrackerAdapter)
@available(iOSApplicationExtension, unavailable)
public class WKStateTrackerAdapter: NSObject, AppStateTrackerAdapter {

    @objc
    public weak var stateTrackerDelegate: AppStateTrackerDelegate?

    private var notificationCenter: NotificationCenter
    private var dispatcher: UADispatcher

    @objc
    public var state: ApplicationState {
        get {
            var result: ApplicationState = .background
            dispatcher.doSync({
                let appState = WKExtension.shared().applicationState
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
            name:WKExtension.applicationDidBecomeActiveNotification,
            object: nil)

        // inactive
        notificationCenter.addObserver(
            self,
            selector: #selector(applicationWillResignActive),
            name: WKExtension.applicationWillResignActiveNotification,
            object: nil)

        // foreground
        notificationCenter.addObserver(
            self,
            selector: #selector(applicationWillEnterForeground),
            name: WKExtension.applicationWillEnterForegroundNotification,
            object: nil)

        // background
        notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: WKExtension.applicationDidEnterBackgroundNotification,
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
