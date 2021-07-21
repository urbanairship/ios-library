import Foundation

@testable
import AirshipCore

public class TestTaskManager : TaskManagerProtocol {
    private var launchHandlers: [String : (UADispatcher, (UATask) -> Void)] = [:]
    public var enqueuedRequests: [(String, UATaskRequestOptions, TimeInterval)] = []
    
    init() {}
    
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

public class TestTask : UATask {
    public var expirationHandler: (() -> Void)?
    
    public var taskID: String
    
    public var requestOptions: UATaskRequestOptions
    
    public var completed = false;
    public var failed = false;
    
    init(_ taskID: String, _ options: UATaskRequestOptions) {
        self.taskID = taskID
        self.requestOptions = options
    }
    
    public func taskCompleted() {
        completed = true
    }
    
    public func taskFailed() {
        failed = true
    }
}
