import Foundation

@testable
import AirshipCore

@objc(UATestTaskManager)
public class TestTaskManager : NSObject, TaskManagerProtocol {
    private var launchHandlers: [String : (UADispatcher, (Task) -> Void)] = [:]
    
    public var enqueuedRequests: [(String, TaskRequestOptions, TimeInterval)] = []
    
    @objc
    public var enqueuedRequestsCount : Int {
        get {
            return enqueuedRequests.count
        }
    }
    
    
    @objc
    public func clearEnqueuedRequests() {
        self.enqueuedRequests.removeAll()
    }
    
    public func register(taskIDs: [String], dispatcher: UADispatcher?, launchHandler: @escaping (Task) -> Void) {
        taskIDs.forEach { register(taskID: $0, dispatcher: dispatcher, launchHandler: launchHandler) }
    }
    
    public func register(taskID: String, dispatcher: UADispatcher?, launchHandler: @escaping (Task) -> Void) {
        launchHandlers[taskID] = (dispatcher ?? UADispatcher.serial(), launchHandler)
    }
    
    public func enqueueRequest(taskID: String, options: TaskRequestOptions) {
        enqueueRequest(taskID: taskID, options: options, initialDelay: 0)
    }
    
    public func enqueueRequest(taskID: String, options: TaskRequestOptions, initialDelay: TimeInterval) {
        enqueuedRequests.append((taskID, options, initialDelay))
    }
    
    @objc
    public func launchSync(taskID: String, options: TaskRequestOptions = TaskRequestOptions.defaultOptions) -> TestTask {
        let testTask = TestTask(taskID, options, 0)
        let dispatcher = self.launchHandlers[taskID]!.0
        let launcher = self.launchHandlers[taskID]!.1
        
        dispatcher.dispatchSync {
            launcher(testTask)
        }
        
        return testTask
    }

    @objc
    public func runEnqueuedRequests(taskID: String) -> TestTask? {
        var task: TestTask?
        for (identifier, options, initialDelay) in enqueuedRequests {
            let testTask = TestTask(identifier, options, initialDelay)
            let dispatcher = self.launchHandlers[identifier]!.0
            let launcher = self.launchHandlers[identifier]!.1

            dispatcher.dispatchSync {
                launcher(testTask)
                if (identifier == taskID) {
                    task = testTask
                }
            }
        }

        return task;

    }
}

@objc(UATestTask)
public class TestTask : NSObject, Task {
    @objc
    public var expirationHandler: (() -> Void)?
    
    @objc
    public var taskID: String
    
    @objc
    public var requestOptions: TaskRequestOptions
    
    @objc
    public var completed = false;
    
    @objc
    public var failed = false;

    @objc
    public var initialDelay: TimeInterval
    
    init(_ taskID: String, _ options: TaskRequestOptions, _ initialDelay: TimeInterval) {
        self.taskID = taskID
        self.requestOptions = options
        self.initialDelay = initialDelay
    }
    
    @objc
    public func taskCompleted() {
        completed = true
    }
    
    @objc
    public func taskFailed() {
        failed = true
    }
}
