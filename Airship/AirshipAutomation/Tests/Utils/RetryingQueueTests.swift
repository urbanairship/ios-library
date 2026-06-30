/* Copyright Airship and Contributors */

import Testing
import Foundation

import AirshipCore
@testable @_spi(AirshipInternal)
import AirshipAutomation
@_spi(AirshipInternal) import AirshipBasement

struct RetryingQueueTests {

    private let taskSleeper: TestTaskSleeper = TestTaskSleeper()

    @Test
    func testState() async throws {
        let queue = RetryingQueue<Int>(
            id: "test",
            taskSleeper: taskSleeper
        )

        let result = await queue.run(name: "testState") { state in
            let runCount: Int = await state.value(key: "runCount") ?? 1
            await state.setValue(runCount + 1, key: "runCount")

            if (runCount == 6) {
                return .success(result: runCount, ignoreReturnOrder: true)
            }

            return .retry
        }

        #expect(6 == result)
    }
    
    @Test
    func testExecutionOrderPriorities() async throws {
        
        let queue = RetryingQueue<Int>(
            id: "test",
            maxConcurrentOperations: 1
        )
        
        let numbers = await withTaskGroup(of: Int.self) { group in
            group.addTask {
                return await queue.run(name: "3", priority: 3) { _ in
                    try await Task.sleep(nanoseconds: 1_000_000)
                    return .success(result: 3, ignoreReturnOrder: false)
                }
            }
            group.addTask {
                return await queue.run(name: "2", priority: 2) { _ in
                    try await Task.sleep(nanoseconds: 1_000_000)
                    return .success(result: 2, ignoreReturnOrder: false)
                }
            }
            group.addTask {
                return await queue.run(name: "1", priority: 1) { _ in
                    try await Task.sleep(nanoseconds: 1_000_000)
                    return .success(result: 1, ignoreReturnOrder: false)
                }
            }

            var result = [Int]()
            
            for await item in group {
                result.append(item)
            }
            
            return result
        }
        
        #expect([1, 2, 3] == numbers)
    }

    @Test
    func testRetryAfter0() async throws {
        let queue = RetryingQueue<Int>(
            id: "test",
            initialBackOff: 10,
            maxBackOff: 60,
            taskSleeper: taskSleeper
        )

        let result = await queue.run(name: "testRetryAfter0") { state in
            let runCount: Int = await state.value(key: "runCount") ?? 1
            await state.setValue(runCount + 1, key: "runCount")

            if (runCount == 1) {
                return .retryAfter(0)
            }

            if (runCount == 3) {
                return .success(result: 0, ignoreReturnOrder: true)
            }

            return .retry

        }

        #expect(0 == result)
        #expect([0, 10] == self.taskSleeper.sleeps)
    }

    @Test
    func testBackOff() async throws {
        let queue = RetryingQueue<Int>(
            id: "test",
            initialBackOff: 10,
            maxBackOff: 60,
            taskSleeper: taskSleeper
        )

        let result = await queue.run(name: "testBackOff") { state in
            let runCount: Int = await state.value(key: "runCount") ?? 1
            await state.setValue(runCount + 1, key: "runCount")

            if (runCount == 6) {
                return .success(result: 0, ignoreReturnOrder: true)
            }

            return .retry

        }

        #expect(0 == result)
        #expect([10, 20, 40, 60, 60] == self.taskSleeper.sleeps)
    }

    @Test
    func testRetryAfterCanExceedMaxBackOff() async throws {
        let queue = RetryingQueue<Int>(
            id: "test",
            initialBackOff: 10,
            maxBackOff: 60,
            taskSleeper: taskSleeper
        )

        let result = await queue.run(name: "testRetryAfterCanExceedMaxBackOff") { state in
            let runCount: Int = await state.value(key: "runCount") ?? 1
            await state.setValue(runCount + 1, key: "runCount")

            if (runCount == 2) {
                return .retryAfter(10000)
            }

            if (runCount == 4) {
                return .success(result: 0, ignoreReturnOrder: true)
            }

            return .retry
        }

        #expect(0 == result)
        #expect([10, 10000, 60] == self.taskSleeper.sleeps)
    }

    @Test
    func testThrowsRetries() async throws {
        let queue = RetryingQueue<Int>(
            id: "test",
            initialBackOff: 10,
            maxBackOff: 60,
            taskSleeper: taskSleeper
        )

        let result = await queue.run(name: "testRetryAfterCanExceedMaxBackOff") { state in
            let isFirstRun: Bool = await state.value(key: "isFirstRun") ?? true
            await state.setValue(false, key: "isFirstRun")

            if (isFirstRun) {
                throw AirshipErrors.error("failed")
            }

            return .success(result: 0)
        }

        #expect(0 == result)
        #expect([10] == self.taskSleeper.sleeps)
    }

    @Test
    func testDeadLock() async throws {
           let queue = RetryingQueue<String>(
            id: "test",
               maxConcurrentOperations: 1,
               maxPendingResults: 1
           )

           let coordinator = DeadlockTestCoordinator()

           await confirmation("Task A completed") { taskACompleted in
               await confirmation("Task B completed") { taskBCompleted in
                   let taskA = Task {
                       let result = await queue.run(name: "Task A", priority: 10) { _ in
                           print("\(Date()): Task A: Started work.")
                           await coordinator.signalTaskBShouldBeAdded()
                           await coordinator.waitForTaskAFinishWork()
                           return .success(result: "A")
                       }
                       #expect(result == "A")
                       taskACompleted()
                   }

                   await coordinator.waitForTaskBToBeAdded()

                   let taskB = Task {
                       let result = await queue.run(name: "Task B", priority: 0) { _ in
                           return .success(result: "B")
                       }
                       #expect(result == "B")
                       taskBCompleted()
                   }

                   await coordinator.signalTaskAFinishWork()

                   await taskA.value
                   await taskB.value
               }
           }
       }

    @Test
    func testRetryDoesNotBlock() async throws {

        let queue = RetryingQueue<Int>(
            id: "test",
            maxConcurrentOperations: 3,
            initialBackOff: 10
        )

        let taskNumber = ActorValue<Int>(1)
        let startedTasks = ActorValue<Int>(0)
        let results = ActorValue<[Int]>([])

        await confirmation("Completed") { completed in
            var tasks: [Task<Void, Never>] = []
            for _ in 1...2 {
                let task = Task { @MainActor in
                    let myTaskNumber = await taskNumber.getAndUpdate { task in
                        task + 1
                    }

                    let result = await queue.run(name: "Task \(myTaskNumber)") { state in
                        let isFirstRun = await state.value(key: "isFirstRun") ?? true
                        await state.setValue(false, key: "isFirstRun")

                        if (isFirstRun) {
                            await startedTasks.update { task in
                               task + 1
                           }
                        }

                        while (await startedTasks.get() != 2) {
                            await Task.yield()
                        }

                        if (myTaskNumber == 1 && isFirstRun) {
                            return .retryAfter(0.2)
                        }

                        return .success(result: myTaskNumber)
                    }

                    await results.update { current in
                        var current = current
                        current.append(result)

                        defer {
                            if (current.count == 2) {
                                completed()
                            }
                        }

                        return current
                    }
                }
                tasks.append(task)
            }

            for task in tasks {
                await task.value
            }
        }
        let resultsValue = await results.get()
        #expect(resultsValue == [2,1])
    }
}

actor ActorValue<T: Sendable> {
    private var value: T
    
    init(_ value: T) {
        self.value = value
    }
    
    func set(_ value: T) {
        self.value = value
    }
    
    func get() -> T {
        return value
    }
    
    func getAndUpdate(block: @Sendable (T) -> T) -> T {
        let value = value
        self.value = block(self.value)
        return value
    }
    
    
    func update(block: @Sendable (T) -> T) {
        self.value = block(self.value)
    }
}

final class TestTaskSleeper : AirshipTaskSleeper, @unchecked Sendable {
    var sleeps : [TimeInterval] = []

    func sleep(timeInterval: TimeInterval) async throws {
        sleeps.append(timeInterval)
        try await self.onSleep?(sleeps)
        await Task.yield()
    }

    var onSleep: (([TimeInterval]) async throws -> Void)?
}

private actor DeadlockTestCoordinator {
    private var taskBShouldBeAddedContinuation: CheckedContinuation<Void, Never>?
    private var taskAFinishWorkContinuation: CheckedContinuation<Void, Never>?

    func waitForTaskBToBeAdded() async {
        await withCheckedContinuation { continuation in
            self.taskBShouldBeAddedContinuation = continuation
        }
    }

    func signalTaskBShouldBeAdded() {
        taskBShouldBeAddedContinuation?.resume()
    }

    func waitForTaskAFinishWork() async {
        await withCheckedContinuation { continuation in
            self.taskAFinishWorkContinuation = continuation
        }
    }

    func signalTaskAFinishWork() {
        taskAFinishWorkContinuation?.resume()
    }
}
