/* Copyright Airship and Contributors */

import UIKit

/**
 * @note For internal use only. :nodoc:
 */
@objc
public class UATaskManager : NSObject {

    private static let initialBackOff = 30.0
    private static let maxBackOff = 120.0
    private static let minBackgroundTime = 30.0

    private var launcherMap: [String : [UATaskLauncher]] = [:]
    private var currentRequests: [String : [UATaskRequest]] = [:]
    private var waitingConditionsRequests: [UATaskRequest] = []
    private var retryingRequests: [UATaskRequest] = []
    
    private let requestsLock = Lock()

    private let application: UIApplication
    private let dispatcher: UADispatcher
    private let networkMonitor: UANetworkMonitor

    @objc
    public static let shared = UATaskManager(application: UIApplication.shared,
                                             notificationCenter: NotificationCenter.default,
                                             dispatcher: UADispatcher.global,
                                             networkMonitor: UANetworkMonitor())

    @objc
    public init(application: UIApplication,
                notificationCenter: NotificationCenter,
                dispatcher: UADispatcher,
                networkMonitor: UANetworkMonitor) {

        self.application = application
        self.dispatcher = dispatcher
        self.networkMonitor = networkMonitor

        super.init()

        notificationCenter.addObserver(
            self,
            selector: #selector(didBecomeActive),
            name: UAAppStateTracker.didBecomeActiveNotification,
            object: nil)

        notificationCenter.addObserver(
            self,
            selector: #selector(didEnterBackground),
            name: UAAppStateTracker.didEnterBackgroundNotification,
            object: nil)

        self.networkMonitor.connectionUpdates = {  [weak self] _ in
            self?.retryWaitingConditions()
        }
    }

    @objc(registerForTaskWithIDs:dispatcher:launchHandler:)
    public func register(taskIDs: [String], dispatcher: UADispatcher?, launchHandler: @escaping (UATask) -> Void) {
        taskIDs.forEach({ taskID in
            register(taskID: taskID, dispatcher: dispatcher, launchHandler: launchHandler)
        })
    }

    @objc(registerForTaskWithID:dispatcher:launchHandler:)
    public func register(taskID: String, dispatcher: UADispatcher?, launchHandler: @escaping (UATask) -> Void) {
        let taskLauncher = UATaskLauncher(dispatcher: dispatcher, launchHandler: launchHandler)

        requestsLock.sync {
            if (self.launcherMap[taskID] == nil) {
                self.launcherMap[taskID] = []
            }
            self.launcherMap[taskID]?.append(taskLauncher)
        }
    }


    @objc(enqueueRequestWithID:options:)
    public func enqueueRequest(taskID: String, options: UATaskRequestOptions) {
        self.enqueueRequest(taskID: taskID, options: options, initialDelay: 0)
    }

    @objc(enqueueRequestWithID:options:initialDelay:)
    public func enqueueRequest(taskID: String, options: UATaskRequestOptions, initialDelay: TimeInterval) {
        let launchers = self.launchers(for: taskID)
        guard launchers.count > 0 else {
            return
        }

        let requests = launchers.map { UATaskRequest(taskID: taskID, options: options, launcher: $0) }

        requestsLock.sync {
            let currentRequestsForID = self.currentRequests[taskID]

            switch (options.conflictPolicy) {
            case .keep:
                if (currentRequestsForID?.count ?? 0 > 0) {
                    AirshipLogger.trace("Request already scheduled, ignoring new request \(taskID)")
                } else {
                    self.currentRequests[taskID] = requests
                }

            case .append:
                var appended = currentRequestsForID ?? []
                appended.append(contentsOf: requests)
                self.currentRequests[taskID] = appended

            case .replace:
                if (currentRequestsForID?.count ?? 0 > 0) {
                    AirshipLogger.trace("Request already scheduled, replacing with new request \(taskID)")
                }
                self.currentRequests[taskID] = requests
            }
        }

        self.initiateRequests(requests, initialDelay: initialDelay)
    }

    private func launchers(for taskID: String) -> [UATaskLauncher] {
        var launchers : [UATaskLauncher]? = nil
        requestsLock.sync {
            launchers = self.launcherMap[taskID]
        }
        return launchers ?? []
    }

    private func initiateRequests(_ requests: [UATaskRequest], initialDelay: TimeInterval) {
        requests.forEach({ request in
            if (initialDelay > 0) {
                self.dispatcher.dispatch(after: initialDelay, block: { [weak self] in
                    self?.attemptRequest(request, nextBackOff: UATaskManager.initialBackOff)
                })
            } else {
                self.attemptRequest(request, nextBackOff: UATaskManager.initialBackOff)
            }
        })
    }

    private func retryRequest(_ request: UATaskRequest, delay: TimeInterval) {
        requestsLock.sync {
            self.retryingRequests.append(request)
        }

        self.dispatcher.dispatch(after: delay) { [weak self] in
            guard let strongSelf = self else {
                return
            }

            var launch = false
            strongSelf.requestsLock.sync {
                if let index = strongSelf.retryingRequests.firstIndex(where: { $0 === request }) {
                    strongSelf.retryingRequests.remove(at: index)
                    launch = true
                }
            }

            if (launch) {
                strongSelf.attemptRequest(request, nextBackOff: Swift.min(UATaskManager.maxBackOff, delay * 2))
            }
        }
    }

    private func attemptRequest(_ request: UATaskRequest, nextBackOff: TimeInterval) {
        guard self.isRequestCurrent(request) else {
            return
        }

        guard self.checkRequestRequirements(request) else {
            requestsLock.sync {
                self.waitingConditionsRequests.append(request)
            }
            return
        }

        var backgroundTask = UIBackgroundTaskIdentifier.invalid
        let task = UAExpirableTask(taskID: request.taskID, requestOptions: request.options) { [weak self] result in
            guard let strongSelf = self else {
                return
            }

            if (strongSelf.isRequestCurrent(request)) {
                if (result) {
                    AirshipLogger.trace("Task \(request.taskID) finished")
                    strongSelf.requestFinished(request)
                } else {
                    AirshipLogger.trace("Task \(request.taskID) failed, will retry in \(nextBackOff) seconds")
                    strongSelf.retryRequest(request, delay: nextBackOff)
                }
            }

            if (backgroundTask != UIBackgroundTaskIdentifier.invalid) {
                strongSelf.application.endBackgroundTask(backgroundTask)
                backgroundTask = UIBackgroundTaskIdentifier.invalid
            }
        }

        backgroundTask = self.application.beginBackgroundTask(withName: "UATaskManager \(request.taskID)") {
            task.expire()
        }

        guard backgroundTask != UIBackgroundTaskIdentifier.invalid else {
            requestsLock.sync {
                self.waitingConditionsRequests.append(request)
            }
            return
        }

        request.launcher.launch(task)
    }

    private func checkRequestRequirements(_ request: UATaskRequest) -> Bool {
        var backgroundTime : TimeInterval = 0.0
        UADispatcher.main.doSync {
            backgroundTime = self.application.backgroundTimeRemaining
        }

        guard backgroundTime >= UATaskManager.minBackgroundTime else {
            return false
        }

        if #available(iOS 12.0, tvOS 12.0, *) {
            if (request.options.isNetworkRequired && !self.networkMonitor.isConnected) {
                return false;
            }
        }

        return true
    }

    private func requestFinished(_ request: UATaskRequest) {
        requestsLock.sync {
            self.currentRequests[request.taskID]?.removeAll(where: { $0 === request })
        }
    }

    private func retryWaitingConditions() {
        var copyWaitinigCondiitions : [UATaskRequest]? = nil

        requestsLock.sync {
            copyWaitinigCondiitions = self.waitingConditionsRequests
            self.waitingConditionsRequests = []
        }

        copyWaitinigCondiitions?.forEach { self.attemptRequest($0, nextBackOff: UATaskManager.initialBackOff) }
    }

    @objc
    func didBecomeActive() {
        self.retryWaitingConditions()
    }

    @objc
    func didEnterBackground() {
        self.retryWaitingConditions()

        var copyRetryingRequests : [UATaskRequest]? = nil

        requestsLock.sync {
            copyRetryingRequests = self.retryingRequests
            self.retryingRequests = []
        }

        copyRetryingRequests?.forEach { self.attemptRequest($0, nextBackOff: UATaskManager.initialBackOff) }
    }

    private func isRequestCurrent(_ request: UATaskRequest) -> Bool {
        var current = false
        requestsLock.sync {
            current = self.currentRequests[request.taskID]?.contains(where: { $0 === request }) ?? false
        }
        return current
    }
}



