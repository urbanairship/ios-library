/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif


/// A concurrent queue that automatically retries an operation.
///
/// Operations that retries will be removed from the queue to return or start work while it waits for the specified
/// backOff. Once the backOff is passed, the operation will be inserted back into the queue in its original FIFO
/// order. When an operation finishes, it will either wait to return its results in FIFO order,
/// or immediately depending on the `ignoreReturnOrder` on the result.
///
/// NOTE: For internal use only. :nodoc:
actor RetryingQueue<T: Sendable> {

    /// Work state that persists across retries
    actor State {
        private var state: [String: any Sendable] = [:]

        /// Sets the value for a given key
        /// - Parameters:
        ///     - value: The value to set
        ///     - key: The key
        func setValue(_ value: (any Sendable)?, key: String) {
            self.state[key] = value
        }

        /// Gets the state for the given key
        /// - Parameters:
        ///     - key: The key
        /// - Returns: The value if it exists
        func value<R: Sendable>(key: String) -> R? {
            return self.state[key] as? R
        }
    }

    /// Prepare result
    enum Result: Sendable {
        /// A successful result
        /// - Parameters:
        ///     - result: The value to return
        ///     - ignoreReturnOrder: `true` to return immediately, `false` to return in FIFO order
        case success(result: T, ignoreReturnOrder: Bool = false)

        /// Retry after the specified value.
        /// - Parameters:
        ///     - retryAfter: The minimum amount of time to wait before retrying.
        case retryAfter(TimeInterval)

        /// Retries using exponential backOff
        case retry
    }

    /// Operation status
    private enum Status: Equatable {
        /// Pending to start running
        case pendingRun
        /// Currently running
        case running
        /// Pending to return its result
        case pendingReturn
        /// Currently retrying
        case retrying
    }

    private struct OperationState {
        let priority: Int
        var id: UInt
        var status: Status = .pendingRun
        private var continuation: CheckedContinuation<Void, Never>? = nil

        init(id: UInt, priority: Int) {
            self.id = id
            self.priority = priority
        }

        mutating func continueWork() {
            self.continuation?.resume()
            self.continuation = nil
        }

        mutating func setContinuation(
            _ continuation: CheckedContinuation<Void, Never>
        ) {
            self.continuation = continuation
        }
    }

    /// Max number of operations to run simultaneously
    private var maxConcurrentOperations: UInt

    /// Max number of pending results before blocking new operations from starting
    private var maxPendingResults: UInt

    /// Initial backOff interval
    private var initialBackOff: TimeInterval

    // Max backOff
    private var maxBackOff: TimeInterval

    private var operationState: [UInt: OperationState] = [:]
    private var nextID: UInt = 1

    private let taskSleeper: any AirshipTaskSleeper

    init(
        config: RemoteConfig.RetryingQueueConfig? = nil,
        taskSleeper: any AirshipTaskSleeper = .shared
    ) {
        self.maxConcurrentOperations = config?.maxConcurrentOperations ?? 3
        self.maxPendingResults = config?.maxPendingResults ?? 2
        self.initialBackOff = config?.initialBackoff ?? 15
        self.maxBackOff = config?.maxBackOff ?? 60
        self.taskSleeper = taskSleeper
    }
    
    init(
        maxConcurrentOperations: UInt = 3,
        maxPendingResults: UInt = 2,
        initialBackOff: TimeInterval = 15,
        maxBackOff: TimeInterval = 60,
        taskSleeper: any AirshipTaskSleeper = .shared
    ) {
        self.maxConcurrentOperations = max(1,maxConcurrentOperations)
        self.maxPendingResults = max(1, maxPendingResults)
        self.initialBackOff = max(1, initialBackOff)
        self.maxBackOff = max(initialBackOff, maxBackOff)
        self.taskSleeper = taskSleeper
    }

    /// Runs work.
    /// - Parameters:
    ///     - name: The name of the operation. Used for logging.
    ///     - block: The operaiton block. `State` will be provided in the block that will persist across
    ///     retries.
    /// - Returns: The successful result value.
    func run(
        name: String,
        priority: Int = 0,
        operation: @escaping @Sendable (State) async throws -> Result
    ) async  -> T {
        let state = State()
        var nextBackOff = initialBackOff

        let operationID = addOperation(priority: priority)

        while(true) {
            await waitForStart(operationID: operationID)
            let task: Task<Result, any Error> = Task {
                return try await operation(state)
            }

            var result: Result
            do {
                result = try await task.value
            } catch {
                AirshipLogger.trace("Retrying \(name) due to uncaught error: \(error)")
                result = .retry
            }

            switch(result) {
            case .success(let result, let ignoreReturnOrder):
                await waitForReturn(operationID: operationID, ignoreReturnOrder: ignoreReturnOrder)
                return result

            case .retryAfter(let retryAfter):
                await waitForRetry(operationID: operationID, retryAfter: retryAfter)
                nextBackOff = min(maxBackOff, max(initialBackOff, retryAfter * 2))

            case .retry:
                await waitForRetry(operationID: operationID, retryAfter: nextBackOff)
                nextBackOff = min(maxBackOff, nextBackOff * 2)
            }

        }
    }

    private func addOperation(priority: Int) -> UInt {
        let state = OperationState(id: nextID, priority: priority)
        nextID += 1
        self.operationState[state.id] = state
        return state.id
    }

    private func waitForRetry(operationID: UInt, retryAfter: TimeInterval) async {
        self.operationState[operationID]?.status = .retrying

        // Allow the next operation to return if they were waiting on this operation
        if let next = nextReturnID() {
            self.operationState[next]?.continueWork()
        }

        // Allow the next work item to start if they were waiting for one to finish running
        if let next = nextPendingOperationID() {
            self.operationState[next]?.continueWork()
        }

        try? await self.taskSleeper.sleep(timeInterval: retryAfter)

        if (retryAfter <= 0) {
            await Task.yield()
        }

        self.operationState[operationID]?.status = .pendingRun
    }

    private func waitForStart(operationID: UInt) async  {
        if (self.nextPendingOperationID() != operationID) {
            await withCheckedContinuation { continuation in
                self.setContinuation(continuation, operationID: operationID)
            }
        }

        self.operationState[operationID]?.status = .running
    }

    private func waitForReturn(operationID: UInt, ignoreReturnOrder: Bool) async {
        self.operationState[operationID]?.status = .pendingReturn

        // Allow the next work item to start if they were waiting for one to finish
        if let next = nextPendingOperationID() {
            self.operationState[next]?.continueWork()
        }

        if (!ignoreReturnOrder && self.nextReturnID() != operationID) {
            // We are not ingoring return order so we need to wait for others to be returned first
            await withCheckedContinuation { continuation in
                self.setContinuation(continuation, operationID: operationID)
            }
        }

        // Operation is finished, remove the state
        self.operationState.removeValue(forKey: operationID)

        // Allow the next operation to return if they were waiting on this operation
        if let next = nextReturnID() {
            self.operationState[next]?.continueWork()
        }

        // Allow the next operation item to start if they were waiting due to maxPendingResults
        if let next = nextPendingOperationID() {
            self.operationState[next]?.continueWork()
        }
    }

    private func nextPendingOperationID() -> UInt? {
        let running = self.operationState.values.filter { $0.status == .running }
        if (running.count > self.maxConcurrentOperations) {
            return nil
        }

        let returning = self.operationState.values.filter { $0.status == .pendingReturn }
        if (returning.count >= self.maxPendingResults) {
            return nil
        }
        
        return self.operationState.values
            .filter { $0.status == .pendingRun }
            .sorted { $0.priority < $1.priority }
            .first?.id
    }

    private func nextReturnID() -> UInt? {
        return self.operationState.values
            .filter { $0.status != .retrying }
            .sorted { $0.priority < $1.priority }
            .first?.id
    }

    private func setContinuation(
        _ continuation: CheckedContinuation<Void, Never>,
        operationID: UInt
    ) {
        self.operationState[operationID]?.setContinuation(continuation)
    }
}

