/* Copyright Airship and Contributors */



enum ThomasFormFieldPendingResult: Equatable, Sendable {
    case valid(ThomasFormField.Result)
    case invalid
    case error

    var isError: Bool {
        if case .error = self {
            return true
        }
        return false
    }
}

@MainActor
protocol ThomasFormFieldPendingRequest: Sendable {
    var result: ThomasFormFieldPendingResult? { get }

    func resultUpdates<T: Sendable>(mapper: @escaping @Sendable (ThomasFormFieldPendingResult?) -> T) -> AsyncStream<T>

    func process(retryErrors: Bool) async

    func cancel()
}

@MainActor
protocol ThomasFormFieldProcessor: Sendable {
    func submit(
        processDelay: TimeInterval,
        resultBlock: @escaping @MainActor @Sendable () async throws -> ThomasFormFieldPendingResult
    ) -> any ThomasFormFieldPendingRequest
}

final class DefaultThomasFormFieldProcessor: ThomasFormFieldProcessor {

    private let date: any AirshipDateProtocol
    private let taskSleeper: any AirshipTaskSleeper

    init(
        date: any AirshipDateProtocol = AirshipDate.shared,
        taskSleeper: any AirshipTaskSleeper  = DefaultAirshipTaskSleeper()
    ) {
        self.date = date
        self.taskSleeper = taskSleeper
    }

    @MainActor
    func submit(
        processDelay: TimeInterval,
        resultBlock: @escaping @MainActor @Sendable () async throws -> ThomasFormFieldPendingResult
    ) -> any ThomasFormFieldPendingRequest {
        AsyncOperation(
            date: self.date,
            taskSleeper: self.taskSleeper,
            processDelay: processDelay,
            resultBlock: resultBlock
        )
    }

    @MainActor
    final class AsyncOperation: ThomasFormFieldPendingRequest {
        var result: ThomasFormFieldPendingResult? {
            self.lastResult
        }

        func resultUpdates<T: Sendable>(mapper: @escaping @Sendable (ThomasFormFieldPendingResult?) -> T) -> AsyncStream<T> {
            return AsyncStream { continuation in
                let id = UUID().uuidString
                onResults[id] = { [continuation] result in
                    continuation.yield(mapper(result))
                }

                continuation.yield(mapper(lastResult))

                continuation.onTermination = { [weak self] _ in
                    Task { @MainActor in
                        self?.onResults[id] = nil
                    }
                }
            }
        }

        private var onResults: [String: (ThomasFormFieldPendingResult) -> Void] = [:]
        private let resultBlock: @MainActor @Sendable () async throws -> ThomasFormFieldPendingResult

        private let date: any AirshipDateProtocol
        private let taskSleeper: any AirshipTaskSleeper

        private var processingTask: Task<Void, Never>?
        private(set) var lastResult: ThomasFormFieldPendingResult?
        private var nextBackOff: TimeInterval? = nil
        private var lastAttempt: Date?

        private static let initialBackOff: TimeInterval = 3.0
        private static let maxBackfOff: TimeInterval = 15.0

        /// Initializes an asynchronous validator.
        /// - Parameters:
        ///   - date: The `AirshipDateProtocol` instance for date handling.
        ///   - taskSleeper: The `AirshipTaskSleeper` instance for sleeping tasks.
        ///   - processBlock: The async block that produces the result.
        init(
            date: any AirshipDateProtocol,
            taskSleeper: any AirshipTaskSleeper,
            processDelay: TimeInterval,
            resultBlock: @escaping @MainActor @Sendable () async throws -> ThomasFormFieldPendingResult
        ) {
            self.resultBlock = resultBlock
            self.date = date
            self.taskSleeper = taskSleeper
            startProcessing(additionalDelay: processDelay)
        }

        func cancel() {
            self.processingTask?.cancel()
            self.processingTask = nil
        }

        deinit {
            self.processingTask?.cancel()
        }

        func process(retryErrors: Bool) async {
            guard lastResult == nil || (lastResult?.isError == true && retryErrors == true) else {
                return
            }

            guard let processingTask, !processingTask.isCancelled else {
                await startProcessing().value
                return
            }
            
            await processingTask.value

        }

        /// Starts the validation process.
        /// - Returns: The task performing the validation.
        @discardableResult
        private func startProcessing(additionalDelay: TimeInterval? = nil) -> Task<Void, Never> {
            self.lastResult = nil

            let task: Task<Void, Never> = Task { @MainActor [weak self] in
                do {
                    if let additionalDelay {
                        try await self?.taskSleeper.sleep(timeInterval: additionalDelay)
                    }
                    try await self?.processBackOff()
                    try Task.checkCancellation()
                    let result = try await self?.resultBlock()
                    try Task.checkCancellation()
                    self?.processResult(result ?? .error)
                } catch {
                    self?.processResult(.error)
                }
            }

            processingTask = task
            return task
        }

        /// Handles backoff logic if validation fails and a retry is needed.
        /// - Throws: An error if task is cancelled.
        private func processBackOff() async throws {
            guard let nextBackOff, let lastAttempt else { return }
            let remaining = nextBackOff - date.now.timeIntervalSince(lastAttempt)
            if (remaining > 0) {
                try await taskSleeper.sleep(timeInterval: remaining)
            }
        }

        /// Processes the result of a validation, including handling backoff logic.
        /// - Parameter result: The result of the validation.
        private func processResult(_ result: ThomasFormFieldPendingResult)  {
            self.lastResult = result
            self.lastAttempt = self.date.now
            self.onResults.values.forEach { $0(result) }
            self.processingTask = nil

            if case .error = result {
                self.nextBackOff = if let last = self.nextBackOff {
                    min(last * 2, Self.maxBackfOff)
                } else {
                    Self.initialBackOff
                }
            } else {
                self.nextBackOff = nil
            }
        }
    }

}
