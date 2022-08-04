/* Copyright Airship and Contributors */

import UIKit

// NOTE: For internal use only. :nodoc:
@objc(UATaskManager)
@available(iOSApplicationExtension, unavailable)
public class TaskManager : NSObject, TaskManagerProtocol {

    private static let initialBackOff = 30.0
    private static let maxBackOff = 120.0
    private static let minBackgroundTime = 30.0


    static let requestBackgroundTaskNamePrefix = "Airship.TaskManager -  Request: "
    static let rateLimitBackgroundTaskName = "Airship.TaskManager - Background"
    private static let rateLimitBackgroundTimeFilter = 60.0
    private static let rateLimitBackgroundTimeBuffer = 10.0

    private var launcherMap: [String : [TaskLauncher]] = [:]
    private var currentRequests: [String : [TaskRequest]] = [:]
    private var waitingConditionsRequests: [TaskRequest] = []
    private var retryingRequests: [TaskRequest] = []

    private let requestsLock = Lock()

    private let backgroundTasks: BackgroundTasksProtocol
    private let dispatcher: UADispatcher
    private let networkMonitor: NetworkMonitor
    private let rateLimiter: RateLimiter

    @objc
    public static let shared = TaskManager(backgroundTasks: BackgroundTasks(),
                                           notificationCenter: NotificationCenter.default,
                                           dispatcher: UADispatcher.globalDispatcher(.utility),
                                           networkMonitor: NetworkMonitor(),
                                           rateLimiter: RateLimiter())


    init(backgroundTasks: BackgroundTasksProtocol,
         notificationCenter: NotificationCenter,
         dispatcher: UADispatcher,
         networkMonitor: NetworkMonitor,
         rateLimiter: RateLimiter) {

        self.backgroundTasks = backgroundTasks
        self.dispatcher = dispatcher
        self.networkMonitor = networkMonitor
        self.rateLimiter = rateLimiter

        super.init()

        notificationCenter.addObserver(
            self,
            selector: #selector(didBecomeActive),
            name: AppStateTracker.didBecomeActiveNotification,
            object: nil)
        
#if !os(watchOS)
        notificationCenter.addObserver(
            self,
            selector: #selector(didEnterBackground),
            name: AppStateTracker.didEnterBackgroundNotification,
            object: nil)
#endif

        self.networkMonitor.connectionUpdates = {  [weak self] _ in
            self?.retryWaitingConditions()
        }
    }

    @objc(registerForTaskWithIDs:dispatcher:launchHandler:)
    public func register(taskIDs: [String], dispatcher: UADispatcher? = nil, launchHandler: @escaping (AirshipTask) -> Void) {
        taskIDs.forEach({ taskID in
            register(taskID: taskID, dispatcher: dispatcher, launchHandler: launchHandler)
        })
    }

    @objc(registerForTaskWithID:dispatcher:launchHandler:)
    public func register(taskID: String, dispatcher: UADispatcher? = nil, launchHandler: @escaping (AirshipTask) -> Void) {
        let taskLauncher = TaskLauncher(dispatcher: dispatcher ?? UADispatcher.globalDispatcher(.utility),
                                        launchHandler: launchHandler)

        requestsLock.sync {
            if (self.launcherMap[taskID] == nil) {
                self.launcherMap[taskID] = []
            }
            self.launcherMap[taskID]?.append(taskLauncher)
        }
    }

    @objc(setRateLimitForID:rate:timeInterval:error:)
    public func setRateLimit(_ rateLimitID: String, rate: Int, timeInterval: TimeInterval) throws {
        try self.rateLimiter.set(rateLimitID, rate: rate, timeInterval: timeInterval)
    }

    @objc(enqueueRequestWithID:options:)
    public func enqueueRequest(taskID: String, options: TaskRequestOptions) {
        self.enqueueRequest(taskID: taskID, options: options, initialDelay: 0)
    }

    @objc(enqueueRequestWithID:options:initialDelay:)
    public func enqueueRequest(taskID: String, options: TaskRequestOptions, initialDelay: TimeInterval) {
        self.enqueueRequest(taskID: taskID, rateLimitIDs: [], options: options, minDelay: initialDelay)
    }

    @objc(enqueueRequestWithID:rateLimitIDs:options:)
    public func enqueueRequest(taskID: String, rateLimitIDs: [String], options: TaskRequestOptions) {
        self.enqueueRequest(taskID: taskID, rateLimitIDs: rateLimitIDs, options: options, minDelay: 0)
    }

    @objc(enqueueRequestWithID:rateLimitIDs:options:minDelay:)
    public func enqueueRequest(taskID: String,
                               rateLimitIDs: [String],
                               options: TaskRequestOptions,
                               minDelay: TimeInterval) {
        
        let launchers = self.launchers(for: taskID)
        guard launchers.count > 0 else {
            return
        }

        let requests = launchers.map {
            TaskRequest(taskID: taskID,
                        rateLimitIDs: rateLimitIDs,
                        options: options,
                        launcher: $0)
        }

        var skip = false
        var rateLimitDelay: TimeInterval = 0

        requestsLock.sync {
            let currentRequestsForID = self.currentRequests[taskID]

            switch (options.conflictPolicy) {
            case .keep:
                if (currentRequestsForID?.count ?? 0 > 0) {
                    AirshipLogger.trace("Request already scheduled, ignoring new request \(taskID)")
                    skip = true
                    return
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

            if let delay = taskRateLimitDelay(rateLimitIDs) {
                rateLimitDelay = delay
            }
        }

        if (!skip) {
            self.initiateRequests(requests, initialDelay: max(minDelay, rateLimitDelay))
        }
    }

    private func launchers(for taskID: String) -> [TaskLauncher] {
        var launchers : [TaskLauncher]? = nil
        requestsLock.sync {
            launchers = self.launcherMap[taskID]
        }
        return launchers ?? []
    }

    private func initiateRequests(_ requests: [TaskRequest], initialDelay: TimeInterval) {
        requests.forEach({ request in
            if (initialDelay > 0) {
                self.dispatcher.dispatch(after: initialDelay, block: { [weak self] in
                    self?.attemptRequest(request, nextBackOff: TaskManager.initialBackOff)
                })
            } else {
                self.attemptRequest(request, nextBackOff: TaskManager.initialBackOff)
            }
        })
    }

    private func retryRequest(_ request: TaskRequest, delay: TimeInterval, nextBackOff: TimeInterval) {
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
                strongSelf.attemptRequest(request, nextBackOff: Swift.min(TaskManager.maxBackOff, nextBackOff))
            }
        }
    }

    private func attemptRequest(_ request: TaskRequest, nextBackOff: TimeInterval) {
        guard self.isRequestCurrent(request) else {
            return
        }

        guard self.checkRequestRequirements(request) else {
            requestsLock.sync {
                self.waitingConditionsRequests.append(request)
            }
            return
        }

        let semaphore = Semaphore()
        var backgroundTask: Disposable?
        let task = ExpirableTask(taskID: request.taskID, requestOptions: request.options) { [weak self] result in
            defer {
                semaphore.signal()
            }

            guard let strongSelf = self else {
                return
            }

            if (strongSelf.isRequestCurrent(request)) {
                if (result) {
                    AirshipLogger.trace("Task \(request.taskID) finished")
                    strongSelf.requestFinished(request)
                } else {
                    AirshipLogger.trace("Task \(request.taskID) failed, will retry in \(nextBackOff) seconds")
                    strongSelf.retryRequest(request, delay: nextBackOff, nextBackOff: nextBackOff * 2)
                }
            }

            backgroundTask?.dispose()
        }

        do {
            #if !os(watchOS)
            let name = TaskManager.requestBackgroundTaskNamePrefix + request.taskID
            backgroundTask = try self.backgroundTasks.beginTask(name) {
                task.expire()
            }
            #endif

            request.launcher.dispatcher.dispatchAsync { [weak self] in
                guard let strongSelf = self, strongSelf.isRequestCurrent(request) else { return }

                guard strongSelf.checkRequestRequirements(request) else {
                    strongSelf.requestsLock.sync {
                        strongSelf.waitingConditionsRequests.append(request)
                    }
                    return
                }

                var rateLimitHit = false
                strongSelf.requestsLock.sync {
                    if let rateLimitDelay = strongSelf.taskRateLimitDelay(request) {
                        strongSelf.retryRequest(request, delay: rateLimitDelay, nextBackOff: nextBackOff)
                        rateLimitHit = true
                    } else {
                        request.rateLimitIDs.forEach { strongSelf.rateLimiter.track($0) }
                    }
                }

                if (!rateLimitHit) {
                    request.launcher.launchHandler(task)
                    semaphore.wait()
                }
            }
        } catch {
            requestsLock.sync {
                self.waitingConditionsRequests.append(request)
            }
            backgroundTask?.dispose()
        }
    }

    private func checkRequestRequirements(_ request: TaskRequest) -> Bool {
        
        #if !os(watchOS)
        var backgroundTime : TimeInterval = 0.0
        UADispatcher.main.doSync {
            backgroundTime = self.backgroundTasks.timeRemaining
        }

        guard backgroundTime >= TaskManager.minBackgroundTime else {
            return false
        }
        #endif

        if #available(iOS 12.0, tvOS 12.0, *) {
            if (request.options.isNetworkRequired && !self.networkMonitor.isConnected) {
                return false;
            }
        }

        return true
    }

    private func requestFinished(_ request: TaskRequest) {
        requestsLock.sync {
            self.currentRequests[request.taskID]?.removeAll(where: { $0 === request })
        }
    }

    private func retryWaitingConditions() {
        var copyWaitinigCondiitions : [TaskRequest]? = nil

        requestsLock.sync {
            copyWaitinigCondiitions = self.waitingConditionsRequests
            self.waitingConditionsRequests = []
        }

        copyWaitinigCondiitions?.forEach { self.attemptRequest($0, nextBackOff: TaskManager.initialBackOff) }
    }

    @objc
    func didBecomeActive() {
        self.retryWaitingConditions()
    }
    
    #if !os(watchOS)
    @objc
    func didEnterBackground() {
        var backgroundTask: Disposable?
        backgroundTask = try? self.backgroundTasks.beginTask(TaskManager.rateLimitBackgroundTaskName) {
            backgroundTask?.dispose()
        }

        guard let backgroundTask = backgroundTask else {
            return
        }

        self.retryWaitingConditions()
        var copyRetryingRequests : [TaskRequest]? = nil

        var rateLimitTime: TimeInterval?
        var maxWaitTime = self.backgroundTasks.timeRemaining - TaskManager.minBackgroundTime - TaskManager.rateLimitBackgroundTimeBuffer
        maxWaitTime = min(maxWaitTime, TaskManager.rateLimitBackgroundTimeFilter)

        requestsLock.sync {
            copyRetryingRequests = self.retryingRequests
            self.retryingRequests = []

            // Find the time we should hold onto a background task to allow for
            // rate limited tasks to execute. Filter all tasks greater than the
            // max wait time, then find the max value of those tasks.
            rateLimitTime = self.currentRequests
                .compactMap { entry in
                    return entry.value
                        .compactMap { taskRateLimitDelay($0.rateLimitIDs) }
                        .filter { $0 <= maxWaitTime }
                        .max()
                }
                .max()
        }

        copyRetryingRequests?.forEach { self.attemptRequest($0, nextBackOff: TaskManager.initialBackOff) }

        if let rateLimitTime = rateLimitTime, maxWaitTime > 0 {
            let actualWaitTime = min(maxWaitTime, rateLimitTime + TaskManager.rateLimitBackgroundTimeBuffer)
            self.dispatcher.dispatch(after: actualWaitTime) {
                backgroundTask.dispose()
            }
        } else {
            backgroundTask.dispose()
        }
    }
    #endif

    private func isRequestCurrent(_ request: TaskRequest) -> Bool {
        var current = false
        requestsLock.sync {
            current = self.currentRequests[request.taskID]?.contains(where: { $0 === request }) ?? false
        }
        return current
    }

    private func taskRateLimitDelay(_ taskRequest: TaskRequest) -> TimeInterval? {
        return taskRateLimitDelay(taskRequest.rateLimitIDs)
    }

    private func taskRateLimitDelay(_ rateLimitIDs: [String]) -> TimeInterval? {
        return rateLimitIDs.compactMap { rateLimitID in
            if case .overLimit(let delay) = self.rateLimiter.status(rateLimitID) {
                return delay
            } else {
                return nil
            }
        }.max()
    }

    private class TaskRequest {
        let taskID: String
        let rateLimitIDs: [String]
        let options: TaskRequestOptions
        let launcher: TaskLauncher

        init(taskID: String, rateLimitIDs: [String], options: TaskRequestOptions, launcher: TaskLauncher) {
            self.taskID = taskID
            self.rateLimitIDs = rateLimitIDs
            self.options = options
            self.launcher = launcher
        }
    }

    private struct TaskLauncher {
        let dispatcher: UADispatcher
        let launchHandler: (AirshipTask) -> Void
    }
}
