import Foundation

@testable
import AirshipCore

@objc(UATestTaskManager)
public class TestTaskManager : NSObject, TaskManagerProtocol {
    private var launchHandlers: [String : (UADispatcher, (UATask) -> Void)] = [:]
    
    public var enqueuedRequests: [(String, UATaskRequestOptions, TimeInterval)] = []
    
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
    
    public func register(taskIDs: [String], dispatcher: UADispatcher?, launchHandler: @escaping (UATask) -> Void) {
        taskIDs.forEach { register(taskID: $0, dispatcher: dispatcher, launchHandler: launchHandler) }
    }
    
    public func register(taskID: String, dispatcher: UADispatcher?, launchHandler: @escaping (UATask) -> Void) {
        launchHandlers[taskID] = (dispatcher ?? UADispatcher.serial(), launchHandler)
    }
    
    public func enqueueRequest(taskID: String, options: UATaskRequestOptions) {
        enqueueRequest(taskID: taskID, options: options, initialDelay: 0)
    }
    
    public func enqueueRequest(taskID: String, options: UATaskRequestOptions, initialDelay: TimeInterval) {
        enqueuedRequests.append((taskID, options, initialDelay))
    }
    
    @objc
    public func launchSync(taskID: String, options: UATaskRequestOptions = UATaskRequestOptions.defaultOptions) -> TestTask {
        let testTask = TestTask(taskID, options)
        let dispatcher = self.launchHandlers[taskID]!.0
        let launcher = self.launchHandlers[taskID]!.1
        
        dispatcher.dispatchSync {
            launcher(testTask)
        }
        
        return testTask
    }
}

@objc(UATestTask)
public class TestTask : NSObject, UATask {
    @objc
    public var expirationHandler: (() -> Void)?
    
    @objc
    public var taskID: String
    
    @objc
    public var requestOptions: UATaskRequestOptions
    
    @objc
    public var completed = false;
    
    @objc
    public var failed = false;
    
    init(_ taskID: String, _ options: UATaskRequestOptions) {
        self.taskID = taskID
        self.requestOptions = options
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
