/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif


/// A concurrent queue that automatically retries an operation with a backoff.
///
/// This queue manages a set of operations, ensuring that they are executed
/// according to priority and concurrency limits. The queue's primary feature is its
/// strict priority model: a higher-priority task will always be processed before
/// a lower-priority task, even if that means a completed low-priority task must
/// wait to return its result.
///
/// Operations can be retried with an exponential backoff. Concurrency is limited
/// by `maxConcurrentOperations`, and backpressure is applied via `maxPendingResults`
/// to prevent too many completed operations from awaiting their turn to return.
///
/// NOTE: For internal use only. :nodoc:
actor RetryingQueue<T: Sendable> {

    /// Work state that persists across retries for a single operation.
    actor State {
        private var state: [String: any Sendable] = [:]

        /// Sets a value for a given key, allowing state to be preserved across retries.
        /// - Parameters:
        ///     - value: The value to set.
        ///     - key: The key.
        func setValue(_ value: (any Sendable)?, key: String) {
            self.state[key] = value
        }

        /// Gets the state for the given key.
        /// - Parameters:
        ///     - key: The key.
        /// - Returns: The value if it exists, cast to the expected type.
        func value<R: Sendable>(key: String) -> R? {
            return self.state[key] as? R
        }
    }

    /// The result of an operation block.
    enum Result: Sendable {
        /// A successful result.
        /// - Parameters:
        ///     - result: The value to return from the `run` method.
        ///     - ignoreReturnOrder: If `true`, the result is returned immediately. If `false`,
        ///     it waits for its turn based on priority.
        case success(result: T, ignoreReturnOrder: Bool = false)

        /// Indicates the operation should be retried after a specific delay.
        /// The next retry will use an exponential backoff based on this value.
        /// - Parameters:
        ///     - retryAfter: The minimum amount of time to wait before retrying.
        case retryAfter(TimeInterval)

        /// Indicates the operation should be retried using the default exponential backoff.
        case retry
    }

    /// The internal status of a queued operation.
    private enum Status: Equatable {
        /// The operation is in the queue, waiting for its turn to run.
        case pendingRun
        /// The operation is currently executing.
        case running
        /// The operation has finished and is waiting for its turn to return the result.
        case pendingReturn
        /// The operation failed and is waiting for the retry delay to pass.
        case retrying
    }

    /// Internal state for tracking each operation.
    private struct OperationState {
        /// The priority of the operation. Lower numbers are higher priority.
        let priority: Int
        /// A unique ID for the operation.
        var id: UInt
        /// The current status of the operation.
        var status: Status = .pendingRun
        /// A continuation used to suspend and resume the operation's task.
        private var continuation: CheckedContinuation<Void, Never>? = nil

        init(id: UInt, priority: Int) {
            self.id = id
            self.priority = priority
        }

        /// Resumes the operation's suspended task.
        mutating func continueWork() {
            self.continuation?.resume()
            self.continuation = nil
        }

        /// Sets the continuation to allow the operation's task to be suspended.
        mutating func setContinuation(
            _ continuation: CheckedContinuation<Void, Never>
        ) {
            self.continuation = continuation
        }
    }

    /// Max number of operations to run simultaneously.
    private var maxConcurrentOperations: UInt

    /// The target maximum number of completed results waiting to be returned. This provides
    /// backpressure against the queue. This limit may be bypassed to allow a
    /// high-priority task to run, preventing a potential deadlock.
    private var maxPendingResults: UInt

    /// The initial delay for exponential backoff retries.
    private var initialBackOff: TimeInterval

    /// The maximum delay for exponential backoff retries.
    private var maxBackOff: TimeInterval

    /// A dictionary holding the state for all current operations.
    private var operationState: [UInt: OperationState] = [:]

    /// A counter to generate unique operation IDs.
    private var nextID: UInt = 1

    private let taskSleeper: any AirshipTaskSleeper

    /// Queue id for logging
    private let id: String

    init(
        id: String,
        config: RemoteConfig.RetryingQueueConfig? = nil,
        taskSleeper: any AirshipTaskSleeper = .shared
    ) {
        self.id = id
        self.maxConcurrentOperations = config?.maxConcurrentOperations ?? 3
        self.maxPendingResults = config?.maxPendingResults ?? 2
        self.initialBackOff = config?.initialBackoff ?? 15
        self.maxBackOff = config?.maxBackOff ?? 60
        self.taskSleeper = taskSleeper
    }

    init(
        id: String,
        maxConcurrentOperations: UInt = 3,
        maxPendingResults: UInt = 2,
        initialBackOff: TimeInterval = 15,
        maxBackOff: TimeInterval = 60,
        taskSleeper: any AirshipTaskSleeper = .shared
    ) {
        self.id = id
        self.maxConcurrentOperations = max(1, maxConcurrentOperations)
        self.maxPendingResults = max(1, maxPendingResults)
        self.initialBackOff = max(1, initialBackOff)
        self.maxBackOff = max(initialBackOff, maxBackOff)
        self.taskSleeper = taskSleeper
    }

    /// Adds and runs an operation on the queue.
    ///
    /// This method returns only when the operation completes successfully. If the
    /// operation fails, it will be automatically retried according to the backoff configuration.
    /// The `async` task calling this method will be suspended until the operation can
    /// start and will remain suspended until it can return its final result.
    ///
    /// - Parameters:
    ///     - name: The name of the operation, used for logging.
    ///     - priority: The priority of the operation. Lower numbers are higher priority.
    ///     - operation: The operation block to execute. It receives a `State` object
    ///     to persist data across retries and must return a `Result`.
    /// - Returns: The successful result value of the operation.
    func run(
        name: String,
        priority: Int = 0,
        operation: @escaping @Sendable (State) async throws -> Result
    ) async  -> T {
        let state = State()
        var nextBackOff = initialBackOff

        let operationID = addOperation(priority: priority)
        AirshipLogger.trace("Queue \(self.id) added: \(name) (priority: \(priority), id: \(operationID))")

        while(true) {
            AirshipLogger.trace("Queue \(self.id) waiting to start: \(name) (id: \(operationID))")
            await waitForStart(operationID: operationID)

            AirshipLogger.trace("Queue \(self.id) starting task for: \(name) (id: \(operationID))")
            let task: Task<Result, any Error> = Task {
                AirshipLogger.trace("Queue \(self.id) running operation for: \(name) (id: \(operationID))")
                return try await operation(state)
            }

            var result: Result
            do {
                result = try await task.value
                AirshipLogger.trace("Queue \(self.id) task finished for: \(name) (id: \(operationID))")
            } catch {
                AirshipLogger.trace("Queue \(self.id) task failed for: \(name) (id: \(operationID)). Error: \(error). Will retry.")
                result = .retry
            }

            switch(result) {
            case .success(let result, let ignoreReturnOrder):
                AirshipLogger.trace("Queue \(self.id) waiting to return success for: \(name) (id: \(operationID)). Ignore order: \(ignoreReturnOrder)")
                await waitForReturn(operationID: operationID, ignoreReturnOrder: ignoreReturnOrder)
                AirshipLogger.trace("Queue \(self.id) returning success for: \(name) (id: \(operationID))")
                return result

            case .retryAfter(let retryAfter):
                AirshipLogger.trace("Queue \(self.id) will retry after delay: \(name) (id: \(operationID)), delay: \(retryAfter)s")
                await waitForRetry(operationID: operationID, retryAfter: retryAfter)
                AirshipLogger.trace("Queue \(self.id) resuming after wait for: \(name) (id: \(operationID))")
                nextBackOff = min(maxBackOff, max(initialBackOff, retryAfter * 2))

            case .retry:
                AirshipLogger.trace("Queue \(self.id) will retry with backoff: \(name) (id: \(operationID)), backoff: \(nextBackOff)s")
                await waitForRetry(operationID: operationID, retryAfter: nextBackOff)
                AirshipLogger.trace("Queue \(self.id) resuming after wait for: \(name) (id: \(operationID))")
                nextBackOff = min(maxBackOff, nextBackOff * 2)
            }
        }
    }

    /// Adds a new operation to the queue and returns its ID.
    private func addOperation(priority: Int) -> UInt {
        let state = OperationState(id: nextID, priority: priority)
        nextID += 1
        self.operationState[state.id] = state
        return state.id
    }

    /// Handles the retry logic for a failed operation.
    /// The operation is moved to the `.retrying` state, other tasks are unblocked,
    /// and this task sleeps for the specified interval before re-queuing itself.
    private func waitForRetry(operationID: UInt, retryAfter: TimeInterval) async {
        self.operationState[operationID]?.status = .retrying

        // Unblock the next operation in the return queue, since this one is no longer returning.
        if let next = nextReturnID() {
            self.operationState[next]?.continueWork()
        }

        // Unblock the next operation waiting to start, since this one is no longer running.
        if let next = nextPendingOperationID() {
            self.operationState[next]?.continueWork()
        }

        try? await self.taskSleeper.sleep(timeInterval: retryAfter)

        if (retryAfter <= 0) {
            await Task.yield()
        }

        // Re-queue the operation to be run again.
        self.operationState[operationID]?.status = .pendingRun
    }

    /// Suspends the current task until it is its turn to start running.
    private func waitForStart(operationID: UInt) async  {
        if (self.nextPendingOperationID() != operationID) {
            await withCheckedContinuation { continuation in
                self.setContinuation(continuation, operationID: operationID)
            }
        }
        self.operationState[operationID]?.status = .running
    }

    /// Suspends the current task until it is its turn to return the result.
    /// After returning, it cleans up and signals other waiting tasks.
    private func waitForReturn(operationID: UInt, ignoreReturnOrder: Bool) async {
        self.operationState[operationID]?.status = .pendingReturn

        // Unblock the next pending operation, as this one is no longer running.
        if let next = nextPendingOperationID() {
            self.operationState[next]?.continueWork()
        }

        // If strict order is required, wait until this is the highest-priority finished task.
        if (!ignoreReturnOrder && self.nextReturnID() != operationID) {
            await withCheckedContinuation { continuation in
                self.setContinuation(continuation, operationID: operationID)
            }
        }

        // Operation is complete, remove its state.
        self.operationState.removeValue(forKey: operationID)

        // Unblock the next operation in the return queue.
        if let next = nextReturnID() {
            self.operationState[next]?.continueWork()
        }

        // Unblock the next pending operation, as the pending results count has decreased.
        if let next = nextPendingOperationID() {
            self.operationState[next]?.continueWork()
        }
    }

    /// Determines the ID of the next operation that should be started.
    ///
    /// This function contains the core scheduling and deadlock-prevention logic.
    /// - Returns: The ID of the next operation to run, or `nil` if no operation can be started.
    private func nextPendingOperationID() -> UInt? {
        let running = self.operationState.values.filter { $0.status == .running }
        if (running.count >= self.maxConcurrentOperations) {
            return nil
        }

        // DEADLOCK PREVENTION: If the highest-priority item in the entire queue is
        // waiting to run, it might be blocked by a lower-priority item that is
        // `.pendingReturn`, which in turn is waiting for the high-priority item.
        // To break this circular dependency, we allow the high-priority item to
        // bypass the `maxPendingResults` check and run immediately.
        if let id = nextReturnID(), self.operationState[id]?.status == .pendingRun {
            return id
        }

        // BACKPRESSURE: If the deadlock condition isn't met, enforce the limit
        // on the number of completed operations waiting to return.
        let returning = self.operationState.values.filter { $0.status == .pendingReturn }
        if (returning.count >= self.maxPendingResults) {
            return nil
        }

        // STANDARD SELECTION: Return the highest-priority task that is pending to run.
        return self.operationState.values
            .filter { $0.status == .pendingRun }
            .sorted { $0.priority < $1.priority }
            .first?.id
    }

    /// Determines the ID of the operation that has the highest priority overall.
    ///
    /// This is used to enforce strict priority ordering. A lower-priority item that has
    /// finished (`.pendingReturn`) will be forced to wait if a higher-priority item
    /// exists, even if it's only just been added (`.pendingRun`).
    ///
    /// - Returns: The ID of the highest-priority active task.
    private func nextReturnID() -> UInt? {
        return self.operationState.values
            .filter { $0.status != .retrying }
            .sorted { $0.priority < $1.priority }
            .first?.id
    }

    /// Associates a continuation with an operation, allowing its task to be suspended.
    private func setContinuation(
        _ continuation: CheckedContinuation<Void, Never>,
        operationID: UInt
    ) {
        self.operationState[operationID]?.setContinuation(continuation)
    }
}
