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
            maxConcurrentOperations: 3
        )

        let gate = TestGate()
        let returnOrder = ActorValue<[Int]>([])

        // Submit highest priority first so each is running before the next starts.
        func submit(priority: Int, value: Int) -> Task<Void, Never> {
            Task {
                let result = await queue.run(name: "\(value)", priority: priority) { _ in
                    await gate.arrive()
                    return .success(result: value, ignoreReturnOrder: false)
                }
                await returnOrder.update { $0 + [result] }
            }
        }

        let first = submit(priority: 1, value: 1)
        await gate.waitForArrivals(1)
        let second = submit(priority: 2, value: 2)
        await gate.waitForArrivals(2)
        let third = submit(priority: 3, value: 3)
        await gate.waitForArrivals(3)

        await gate.open()
        _ = await (first.value, second.value, third.value)

        #expect([1, 2, 3] == (await returnOrder.get()))
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

    @Test(.timeLimit(.minutes(1)))
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
        // A retrying task should not block other queued tasks from completing.
        let queue = RetryingQueue<Int>(
            id: "test",
            maxConcurrentOperations: 1,
            initialBackOff: 10,
            taskSleeper: taskSleeper
        )

        let results = ActorValue<[Int]>([])

        // Hold Task 1 in backoff until Task 2 completes, proving it wasn't blocked.
        self.taskSleeper.onSleep = { _ in
            while await results.get().contains(2) == false {
                await Task.yield()
            }
        }

        let task1 = Task {
            let result = await queue.run(name: "Task 1", priority: 0) { state in
                let isFirstRun = await state.value(key: "isFirstRun") ?? true
                await state.setValue(false, key: "isFirstRun")
                return isFirstRun ? .retryAfter(0.2) : .success(result: 1)
            }
            await results.update { $0 + [result] }
        }

        let task2 = Task {
            let result = await queue.run(name: "Task 2", priority: 1) { _ in
                return .success(result: 2)
            }
            await results.update { $0 + [result] }
        }

        _ = await (task1.value, task2.value)

        #expect((await results.get()) == [2, 1])
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

/// A test barrier: tasks park on `arrive()` until `open()` is called.
actor TestGate {
    private(set) var arrivedCount = 0
    private var parked: [CheckedContinuation<Void, Never>] = []
    private var observers: [(target: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private var isOpen = false

    /// Number of tasks currently parked at the gate.
    var inside: Int { parked.count }

    /// Records an arrival, then parks until `open()` unless already open.
    func arrive() async {
        arrivedCount += 1
        observers.removeAll { observer in
            guard arrivedCount >= observer.target else { return false }
            observer.continuation.resume()
            return true
        }

        guard !isOpen else { return }
        await withCheckedContinuation { parked.append($0) }
    }

    /// Resolves once `arrivedCount` has reached `count`.
    func waitForArrivals(_ count: Int) async {
        guard arrivedCount < count else { return }
        await withCheckedContinuation { observers.append((count, $0)) }
    }

    /// Releases all parked tasks and lets future arrivals pass through.
    func open() {
        isOpen = true
        let continuations = parked
        parked.removeAll()
        continuations.forEach { $0.resume() }
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
