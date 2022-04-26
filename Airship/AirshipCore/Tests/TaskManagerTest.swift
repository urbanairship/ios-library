/* Copyright Airship and Contributors */

import XCTest
@testable
import AirshipCore

class TaskManagerTest: XCTestCase {
    let dispatcher = TestDispatcher()
    let notificationCenter = NotificationCenter()
    let backgroundTasks = TestBackgroundTasks()
    let networkMonitor = TestNetworkMonitor()
    let date = UATestDate(offset: 0, dateOverride: Date())

    lazy var rateLimiter: RateLimiter = {
        return RateLimiter(date: self.date)
    }()

    lazy var taskManager: TaskManager = {
        return TaskManager(backgroundTasks: self.backgroundTasks,
                           notificationCenter: self.notificationCenter,
                           dispatcher: self.dispatcher,
                           networkMonitor: self.networkMonitor,
                           rateLimiter: self.rateLimiter)
    }()

    override func setUp() async throws {
        self.networkMonitor.isConnectedOverride = true
    }

    func testLaunch() throws {
        let backgroundExpectation = self.expectation(description: "background task ended")
        backgroundExpectation.assertForOverFulfill = true
        let backgroundTask = Disposable {
            backgroundExpectation.fulfill()
        }
        self.backgroundTasks.taskHandler = { _, _ in
            return backgroundTask
        }
        self.backgroundTasks.timeRemaining = 45

        let requestOptions = TaskRequestOptions(conflictPolicy: .append,
                                                requiresNetwork: false,
                                                extras: ["neat": "story"])


        let taskExpectation = self.expectation(description: "Task ran")
        taskExpectation.assertForOverFulfill = true
        self.taskManager.register(taskID: "test") { task in
            XCTAssertEqual("test", task.taskID)
            XCTAssertEqual(requestOptions, task.requestOptions)
            task.taskCompleted()
            taskExpectation.fulfill()
        }

        self.taskManager.enqueueRequest(taskID: "test", options: requestOptions)
        self.wait(for: [taskExpectation, backgroundExpectation], timeout: 5)
    }

    func testRetry() throws {
        let backgroundExpectation = self.expectation(description: "background task ended")
        backgroundExpectation.expectedFulfillmentCount = 5

        let requestBackgroundExpectation = self.expectation(description: "request background task")
        requestBackgroundExpectation.expectedFulfillmentCount = 5
        self.backgroundTasks.taskHandler = { _, _ in
            requestBackgroundExpectation.fulfill()
            return Disposable {
                backgroundExpectation.fulfill()
            }
        }
        self.backgroundTasks.timeRemaining = 45

        var attempts = 0
        let taskExpectation = self.expectation(description: "task launched")
        taskExpectation.expectedFulfillmentCount = 5
        self.taskManager.register(taskID: "test", dispatcher: self.dispatcher) { task in
            attempts += 1
            XCTAssertEqual("test", task.taskID)
            task.taskFailed()
            taskExpectation.fulfill()
        }

        let expectations = [backgroundExpectation, requestBackgroundExpectation, taskExpectation]

        // Start
        self.taskManager.enqueueRequest(taskID: "test", options: .defaultOptions)

        var expectedAttempts = 1
        [30.0, 60.0, 120.0, 120.0].forEach {
            expectedAttempts += 1
            self.dispatcher.advanceTime($0)
            XCTAssertEqual(expectedAttempts, attempts)
        }

        self.wait(for: expectations, timeout: 10)
    }

    func testExpire() throws {
        var expirationHandler: (() -> Void)?
        self.backgroundTasks.taskHandler = { _, expireHandler in
            expirationHandler = expireHandler
            return Disposable {}
        }

        self.backgroundTasks.timeRemaining = 45

        let taskExpired = self.expectation(description: "task expired")
        let taskRan = self.expectation(description: "task ran")

        self.taskManager.register(taskID: "test") { task in
            task.expirationHandler = {
                taskExpired.fulfill()
            }
            taskRan.fulfill()
        }

        self.taskManager.enqueueRequest(taskID: "test", options: .defaultOptions)
        self.wait(for: [taskRan], timeout: 10)

        expirationHandler!()
        self.wait(for: [taskExpired], timeout: 10)
    }

    func testEnqueueWithDelay() throws {
        self.backgroundTasks.timeRemaining = 45
        self.backgroundTasks.taskHandler = { _, _ in
            return Disposable {}
        }

        var ran = false
        self.taskManager.register(taskID: "test", dispatcher: self.dispatcher) { task in
            ran = true
            task.taskCompleted()
        }

        self.taskManager.enqueueRequest(taskID: "test", options: .defaultOptions, initialDelay: 100)

        self.dispatcher.advanceTime(99)
        XCTAssertFalse(ran)

        self.dispatcher.advanceTime(1)
        XCTAssertTrue(ran)
    }

    func testConflictPolicyReplace() throws {
        self.backgroundTasks.timeRemaining = 45
        self.backgroundTasks.taskHandler = { _, _ in
            return Disposable {}
        }

        var ran = false
        self.taskManager.register(taskID: "test", dispatcher: self.dispatcher) { task in
            if ran {
                XCTFail()
            }

            ran = true
            XCTAssertEqual("second", task.requestOptions.extras["subtask"] as? String)
            task.taskCompleted()
        }

        let firstOptions = TaskRequestOptions(conflictPolicy: .replace,
                                              requiresNetwork: false,
                                              extras: ["subtask": "first"])

        self.taskManager.enqueueRequest(taskID: "test", options: firstOptions, initialDelay: 10)

        let secondOptions = TaskRequestOptions(conflictPolicy: .replace,
                                              requiresNetwork: false,
                                              extras: ["subtask": "second"])

        self.taskManager.enqueueRequest(taskID: "test", options: secondOptions, initialDelay: 10)

        self.dispatcher.advanceTime(100)
        XCTAssertTrue(ran)
    }

    func testConflictPolicyKeep() throws {
        self.backgroundTasks.timeRemaining = 45
        self.backgroundTasks.taskHandler = { _, _ in
            return Disposable {}
        }

        var ran = false
        self.taskManager.register(taskID: "test", dispatcher: self.dispatcher) { task in
            if ran {
                XCTFail()
            }

            ran = true
            XCTAssertEqual("first", task.requestOptions.extras["subtask"] as? String)
            task.taskCompleted()
        }

        let firstOptions = TaskRequestOptions(conflictPolicy: .keep,
                                              requiresNetwork: false,
                                              extras: ["subtask": "first"])

        self.taskManager.enqueueRequest(taskID: "test", options: firstOptions, initialDelay: 10)

        let secondOptions = TaskRequestOptions(conflictPolicy: .keep,
                                              requiresNetwork: false,
                                              extras: ["subtask": "second"])

        self.taskManager.enqueueRequest(taskID: "test", options: secondOptions, initialDelay: 10)

        self.dispatcher.advanceTime(100)
        XCTAssertTrue(ran)
    }

    func testConflictPolicyAppend() throws {
        self.backgroundTasks.timeRemaining = 45
        self.backgroundTasks.taskHandler = { _, _ in
            return Disposable {}
        }

        var subtasks: [String] = []
        self.taskManager.register(taskID: "test", dispatcher: self.dispatcher) { task in
            subtasks.append(task.requestOptions.extras["subtask"] as! String)
            task.taskCompleted()
        }

        let firstOptions = TaskRequestOptions(conflictPolicy: .append,
                                              requiresNetwork: false,
                                              extras: ["subtask": "first"])

        self.taskManager.enqueueRequest(taskID: "test", options: firstOptions, initialDelay: 10)
        let secondOptions = TaskRequestOptions(conflictPolicy: .append,
                                              requiresNetwork: false,
                                              extras: ["subtask": "second"])

        self.taskManager.enqueueRequest(taskID: "test", options: secondOptions, initialDelay: 10)
        self.dispatcher.advanceTime(100)
        XCTAssertEqual(["first", "second"], subtasks)
    }

    func testRequiresNetwork() throws {
        self.networkMonitor.isConnectedOverride = false
        self.backgroundTasks.timeRemaining = 45
        self.backgroundTasks.taskHandler = { _, _ in
            return Disposable {}
        }

        var ran = false
        self.taskManager.register(taskID: "test", dispatcher: self.dispatcher) { task in
            if ran {
                XCTFail()
            }

            ran = true
            task.taskCompleted()
        }

        let options = TaskRequestOptions(conflictPolicy: .keep,
                                         requiresNetwork: true,
                                         extras: nil)

        self.taskManager.enqueueRequest(taskID: "test", options: options)
        XCTAssertFalse(ran)

        self.networkMonitor.isConnectedOverride = true
        XCTAssertTrue(ran)
    }

    func testNotEnoughBackgroundTime() throws {
        self.backgroundTasks.timeRemaining = 29
        self.backgroundTasks.taskHandler = { _, _ in
            return Disposable {}
        }

        var ran = false
        self.taskManager.register(taskID: "test", dispatcher: self.dispatcher) { task in
            if ran {
                XCTFail()
            }

            ran = true
            task.taskCompleted()
        }

        let options = TaskRequestOptions(conflictPolicy: .keep,
                                         requiresNetwork: true,
                                         extras: nil)

        self.taskManager.enqueueRequest(taskID: "test", options: options)
        XCTAssertFalse(ran)

        self.backgroundTasks.timeRemaining = 30
        self.notificationCenter.post(name: AppStateTracker.didBecomeActiveNotification, object: nil)
        XCTAssertTrue(ran)
    }

    func testInvalidBackgroundTask() throws {
        self.backgroundTasks.timeRemaining = 45
        self.backgroundTasks.taskHandler = { _, _ in
            return nil
        }

        var ran = false
        self.taskManager.register(taskID: "test", dispatcher: self.dispatcher) { task in
            if ran {
                XCTFail()
            }

            ran = true
            task.taskCompleted()
        }

        let options = TaskRequestOptions(conflictPolicy: .keep,
                                         requiresNetwork: true,
                                         extras: nil)

        self.taskManager.enqueueRequest(taskID: "test", options: options)
        XCTAssertFalse(ran)

        self.backgroundTasks.taskHandler = { _, _ in
            return Disposable()
        }

        self.notificationCenter.post(name: AppStateTracker.didBecomeActiveNotification, object: nil)
        XCTAssertTrue(ran)
    }

    func testAttemptPendingOnBackground() throws {
        self.backgroundTasks.timeRemaining = 45
        self.backgroundTasks.taskHandler = { _, _ in
            return Disposable {}
        }

        var attempts = 0
        self.taskManager.register(taskID: "test", dispatcher: self.dispatcher) { task in
            attempts += 1
            task.taskFailed()
        }

        // Start
        self.taskManager.enqueueRequest(taskID: "test", options: .defaultOptions)
        XCTAssertEqual(1, attempts)

        self.notificationCenter.post(name: AppStateTracker.didEnterBackgroundNotification, object: nil)
        XCTAssertEqual(2, attempts)
    }

    func testWaitForRateLimitTasks() throws {
        self.backgroundTasks.timeRemaining = 4000

        try self.taskManager.setRateLimit("foo", rate: 1, timeInterval: 48)
        self.taskManager.register(taskID: "foo", dispatcher: self.dispatcher) { _ in }
        self.rateLimiter.track("foo")

        try self.taskManager.setRateLimit("bar", rate: 1, timeInterval: 90)
        self.taskManager.register(taskID: "bar", dispatcher: self.dispatcher) { _ in }
        self.rateLimiter.track("bar")

        var bgTaskFinished = false
        var bgTaskStarted = false
        self.backgroundTasks.taskHandler = { name, _ in
            guard name == TaskManager.rateLimitBackgroundTaskName else {
                return Disposable()
            }

            if (bgTaskStarted) {
                XCTFail()
            }
            bgTaskStarted = true
            return Disposable {
                if (bgTaskFinished) {
                    XCTFail()
                }
                bgTaskFinished = true
            }
        }

        self.taskManager.enqueueRequest(taskID: "foo", rateLimitID: "foo", options: .defaultOptions)
        self.taskManager.enqueueRequest(taskID: "bar", rateLimitID: "bar", options: .defaultOptions)

        self.notificationCenter.post(name: AppStateTracker.didEnterBackgroundNotification, object: nil)

        XCTAssertTrue(bgTaskStarted)
        XCTAssertFalse(bgTaskFinished)

        // 48(foo) + 10(buffer) - 1 (right before)
        self.dispatcher.advanceTime(57)
        XCTAssertFalse(bgTaskFinished)

        self.dispatcher.advanceTime(1)
        XCTAssertTrue(bgTaskFinished)
    }

    func testWaitForRateLimitTasksInsufficientBackgroundTime() throws {
        // Tasks require at least 30 seconds
        self.backgroundTasks.timeRemaining = 30

        try self.taskManager.setRateLimit("foo", rate: 1, timeInterval: 1)
        self.taskManager.register(taskID: "foo", dispatcher: self.dispatcher) { _ in }
        self.rateLimiter.track("foo")

        var bgTaskFinished = false
        var bgTaskStarted = false
        self.backgroundTasks.taskHandler = { name, _ in
            guard name == TaskManager.rateLimitBackgroundTaskName else {
                return Disposable()
            }

            if (bgTaskStarted) {
                XCTFail()
            }
            bgTaskStarted = true
            return Disposable {
                if (bgTaskFinished) {
                    XCTFail()
                }
                bgTaskFinished = true
            }
        }

        self.taskManager.enqueueRequest(taskID: "foo", rateLimitID: "foo", options: .defaultOptions)
        self.notificationCenter.post(name: AppStateTracker.didEnterBackgroundNotification, object: nil)

        XCTAssertTrue(bgTaskStarted)
        XCTAssertTrue(bgTaskFinished)
    }

    func testWaitForRateLimitTasksBeyondMaxTime() throws {
        self.backgroundTasks.timeRemaining = 400
        try self.taskManager.setRateLimit("foo", rate: 1, timeInterval: 61)
        self.taskManager.register(taskID: "foo", dispatcher: self.dispatcher) { _ in }
        self.rateLimiter.track("foo")

        var bgTaskFinished = false
        var bgTaskStarted = false
        self.backgroundTasks.taskHandler = { name, _ in
            guard name == TaskManager.rateLimitBackgroundTaskName else {
                return Disposable()
            }

            if (bgTaskStarted) {
                XCTFail()
            }
            bgTaskStarted = true
            return Disposable {
                if (bgTaskFinished) {
                    XCTFail()
                }
                bgTaskFinished = true
            }
        }

        self.taskManager.enqueueRequest(taskID: "foo", rateLimitID: "foo", options: .defaultOptions)
        self.notificationCenter.post(name: AppStateTracker.didEnterBackgroundNotification, object: nil)

        XCTAssertTrue(bgTaskStarted)
        XCTAssertTrue(bgTaskFinished)
    }

    func testWaitForRateLimitTasksNoTasks() throws {
        self.backgroundTasks.timeRemaining = 400
        try self.taskManager.setRateLimit("foo", rate: 1, timeInterval: 61)
        self.taskManager.register(taskID: "foo", dispatcher: self.dispatcher) { _ in }
        self.rateLimiter.track("foo")

        var bgTaskFinished = false
        var bgTaskStarted = false
        self.backgroundTasks.taskHandler = { name, _ in
            guard name == TaskManager.rateLimitBackgroundTaskName else {
                return Disposable()
            }

            if (bgTaskStarted) {
                XCTFail()
            }
            bgTaskStarted = true
            return Disposable {
                if (bgTaskFinished) {
                    XCTFail()
                }
                bgTaskFinished = true
            }
        }

        self.notificationCenter.post(name: AppStateTracker.didEnterBackgroundNotification, object: nil)
        XCTAssertTrue(bgTaskStarted)
        XCTAssertTrue(bgTaskFinished)
    }

    func testRateLimit() throws {
        self.backgroundTasks.timeRemaining = 45
        self.backgroundTasks.taskHandler = { _, _ in
            return Disposable {}
        }

        var attempts = 0
        self.taskManager.register(taskID: "test", dispatcher: self.dispatcher) { task in
            attempts += 1
            task.taskCompleted()
        }

        self.taskManager.enqueueRequest(taskID: "test", options: .defaultOptions)
        self.taskManager.enqueueRequest(taskID: "test", options: .defaultOptions)
        XCTAssertEqual(2, attempts)

        let rateLimitID = "oncePerMinute"
        try self.taskManager.setRateLimit(rateLimitID, rate: 1, timeInterval: 60)

        self.taskManager.enqueueRequest(taskID: "test", rateLimitID: rateLimitID, options: .defaultOptions)
        self.taskManager.enqueueRequest(taskID: "test", rateLimitID: rateLimitID, options: .defaultOptions)
        XCTAssertEqual(3, attempts)

        self.date.offset += 60
        self.dispatcher.advanceTime(60)

        XCTAssertEqual(4, attempts)

        self.taskManager.enqueueRequest(taskID: "test", rateLimitID: rateLimitID, options: .defaultOptions)
        self.taskManager.enqueueRequest(taskID: "test", rateLimitID: rateLimitID, options: .defaultOptions)
        self.taskManager.enqueueRequest(taskID: "test", rateLimitID: rateLimitID, options: .defaultOptions)
        self.taskManager.enqueueRequest(taskID: "test", rateLimitID: rateLimitID, options: .defaultOptions)
        self.taskManager.enqueueRequest(taskID: "test", rateLimitID: rateLimitID, options: .defaultOptions)

        self.date.offset += 6000
        self.dispatcher.advanceTime(6000)
        XCTAssertEqual(5, attempts)
    }
}

