import Foundation

@testable
import AirshipCore
import SwiftUI

@objc(UATestTaskManager)
public class TestTaskManager : NSObject, TaskManagerProtocol {

    public struct Pending {
        let taskID: String
        let rateLimitIDs: [String]
        let options: TaskRequestOptions
        let minDelay: TimeInterval
    }

    public struct RateLimit {
        let rate: Int
        let timeInterval: TimeInterval
    }

    private var launchHandlers: [String : (UADispatcher, (AirshipTask) -> Void)] = [:]
    
    public var enqueuedRequests: [Pending] = []
    public var rateLimits: [String: RateLimit] = [:]

    @objc
    public var enqueuedRequestsCount : Int {
        get {
            return enqueuedRequests.count
        }
    }
    
    public func setRateLimit(_ rateLimitID: String, rate: Int, timeInterval: TimeInterval) throws {
        rateLimits[rateLimitID] = RateLimit(rate: rate, timeInterval: timeInterval)
    }

    @objc
    public func clearEnqueuedRequests() {
        self.enqueuedRequests.removeAll()
    }
    
    public func register(taskIDs: [String], dispatcher: UADispatcher?, launchHandler: @escaping (AirshipTask) -> Void) {
        taskIDs.forEach { register(taskID: $0, dispatcher: dispatcher, launchHandler: launchHandler) }
    }
    
    public func register(taskID: String, dispatcher: UADispatcher?, launchHandler: @escaping (AirshipTask) -> Void) {
        launchHandlers[taskID] = (dispatcher ?? UADispatcher.serial(), launchHandler)
    }
    
    public func enqueueRequest(taskID: String, options: TaskRequestOptions) {
        enqueueRequest(taskID: taskID, options: options, initialDelay: 0)
    }
    
    public func enqueueRequest(taskID: String, options: TaskRequestOptions, initialDelay: TimeInterval) {
        enqueueRequest(taskID: taskID, rateLimitIDs: [], options: options, minDelay: initialDelay)
    }

    public func enqueueRequest(taskID: String,
                               rateLimitIDs: [String],
                               options: TaskRequestOptions) {
        enqueueRequest(taskID: taskID, rateLimitIDs: rateLimitIDs, options: options, minDelay: 0)
    }

    public func enqueueRequest(taskID: String,
                               rateLimitIDs: [String],
                               options: TaskRequestOptions,
                               minDelay: TimeInterval) {

        let pending = Pending(taskID: taskID,
                              rateLimitIDs: rateLimitIDs,
                              options: options,
                              minDelay: minDelay)

        enqueuedRequests.append(pending)
    }

    
    @objc
    public func launchSync(taskID: String, options: TaskRequestOptions = TaskRequestOptions.defaultOptions) -> TestTask {

        let pending = Pending(taskID: taskID, rateLimitIDs: [], options: options, minDelay: 0)
        return self.launchTask(pending)
    }

    @objc
    public func runEnqueuedRequests(taskID: String) -> TestTask? {
        for pending in enqueuedRequests {
            if (pending.taskID == taskID) {
                return self.launchTask(pending)
            }
        }

        return nil

    }

    private func launchTask(_ pending: Pending) -> TestTask {
        let semaphore = Semaphore()
        let testTask = TestTask(pending) {
            semaphore.signal()
        }
        let dispatcher = self.launchHandlers[pending.taskID]!.0
        let launcher = self.launchHandlers[pending.taskID]!.1

        dispatcher.dispatchSync {
            launcher(testTask)
            semaphore.wait()
        }

        return testTask;
    }
}

@objc(UATestTask)
public class TestTask : NSObject, AirshipTask {
    @objc
    public var expirationHandler: (() -> Void)?

    @objc
    public var completionHandler: (() -> Void)?
    
    @objc
    public var taskID: String
    
    @objc
    public var requestOptions: TaskRequestOptions
    
    @objc
    public var completed = false;
    
    @objc
    public var failed = false;

    @objc
    public var minDelay: TimeInterval

    @objc
    public var rateLimitIDs: [String]

    private let onFinish: () -> Void

    init(_ pending: TestTaskManager.Pending, onFinish: @escaping () -> Void) {
        self.taskID = pending.taskID
        self.requestOptions = pending.options
        self.minDelay = pending.minDelay
        self.rateLimitIDs = pending.rateLimitIDs
        self.onFinish = onFinish
    }
    
    @objc
    public func taskCompleted() {
        completed = true
        completionHandler?()
        onFinish()
    }
    
    @objc
    public func taskFailed() {
        failed = true
        completionHandler?()
        onFinish()
    }
}
