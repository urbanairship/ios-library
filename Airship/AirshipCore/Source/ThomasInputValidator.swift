/* Copyright Airship and Contributors */

import Foundation

@MainActor
final class ThomasInputValidator: Sendable {

    /// Represents the possible outcomes of a validation process.
    enum Result {
        case valid       // The input is valid.
        case invalid     // The input is invalid.
        case error       // An error occurred during validation.
    }

    /// Represents early validation handling strategy.
    enum EarlyValidation {
        case never        // No early validation.
        case delay(TimeInterval)  // Delay the validation by the specified time interval.
    }

    private enum Method: Sendable {
        case just(Result)  // Immediate validation result.
        case async(AsyncValidator)  // Asynchronous validation using an `AsyncValidator`.
    }

    private let method: Method

    /// Initializes a validator instance.
    /// - Parameter method: The method used to perform the validation.
    private init(_ method: Method) {
        self.method = method
    }

    /// Creates an asynchronous validation.
    /// - Parameters:
    ///   - earlyValidation: Defines whether to delay the validation, or never do it early.
    ///   - date: The `AirshipDateProtocol` instance for date handling.
    ///   - taskSleeper: The `AirshipTaskSleeper` instance for sleeping tasks.
    ///   - block: The validation block that should return a boolean value asynchronously.
    /// - Returns: A `ThomasInputValidator` instance with asynchronous validation.
    static func async(
        earlyValidation: EarlyValidation = .delay(1.0),
        date: any AirshipDateProtocol = AirshipDate.shared,
        taskSleeper: any AirshipTaskSleeper = DefaultAirshipTaskSleeper.shared,
        block: @escaping @MainActor @Sendable () async throws -> Bool
    ) -> Self {
        .init(
            .async(
                AsyncValidator(
                    earlyValidation: earlyValidation,
                    date: date,
                    taskSleeper: taskSleeper,
                    validatorBlock: block
                )
            )
        )
    }

    /// Creates an immediate validation.
    /// - Parameter value: A boolean value that determines whether the input is valid or invalid.
    /// - Returns: A `ThomasInputValidator` instance with the validation result.
    static func just(_ value: Bool) -> Self {
        .init(.just(value ? .valid : .invalid))
    }

    /// Gets the result of the validation.
    /// - Returns: The `Result` of the validation process, or `nil` if not available.
    var result: Result? {
        switch(self.method) {
        case .async(let asyncValidator):
            return asyncValidator.lastResult
        case .just(let value):
            return value
        }
    }

    /// Waits for the validation result, and retries if necessary.
    /// - Returns: The validation `Result`.
    func waitResult() async -> Result {
        if let result, result != .error {
            return result
        }

        return switch(self.method) {
        case .async(let asyncValidator):
            await asyncValidator.validate()
        case .just(let value):
            value
        }
    }

    @MainActor
    final class AsyncValidator: Sendable {
        private let validatorBlock: @MainActor @Sendable () async throws -> Bool
        private let date: any AirshipDateProtocol
        private let taskSleeper: any AirshipTaskSleeper

        private var validationTask: Task<Result, Never>?
        private var scheduleValidationTask: Task<Void, any Error>? = nil
        private(set) var lastResult: Result?
        private var nextBackOff: TimeInterval? = nil
        private var lastAttempt: Date?

        private static let initialBackOff: TimeInterval = 3.0
        private static let maxBackfOff: TimeInterval = 15.0

        /// Initializes an asynchronous validator.
        /// - Parameters:
        ///   - earlyValidation: Defines whether to delay the validation, or never do it early.
        ///   - date: The `AirshipDateProtocol` instance for date handling.
        ///   - taskSleeper: The `AirshipTaskSleeper` instance for sleeping tasks.
        ///   - validatorBlock: The validation block that should return a boolean value asynchronously.
        init(
            earlyValidation: EarlyValidation,
            date: any AirshipDateProtocol,
            taskSleeper: any AirshipTaskSleeper,
            validatorBlock: @escaping @Sendable () async throws -> Bool
        ) {
            self.validatorBlock = validatorBlock
            self.date = date
            self.taskSleeper = taskSleeper

            switch(earlyValidation) {
            case .never:
                break
            case .delay(let delay):
                if delay > 0 {
                    self.scheduleValidationTask = Task { @MainActor [weak self] in
                        try await taskSleeper.sleep(timeInterval: delay)
                        try Task.checkCancellation()
                        self?.startValidation()
                    }
                } else {
                    startValidation()
                }
            }
        }

        deinit {
            self.scheduleValidationTask?.cancel()
            self.validationTask?.cancel()
        }

        /// Validates the input asynchronously.
        /// - Returns: The result of the validation (`Result`).
        public func validate() async -> Result {
            // Use the last result if we have it and it's not an error
            if let lastResult, lastResult != .error {
                return lastResult
            }

            // If we do not have a last result but a task, use it
            if lastResult == nil, let validationTask, validationTask.isCancelled == false {
                return await validationTask.value
            }

            // Cancel and start a new task
            self.scheduleValidationTask?.cancel()
            self.validationTask?.cancel()
            return await startValidation().value
        }

        /// Starts the validation process.
        /// - Returns: The task performing the validation.
        @discardableResult
        private func startValidation() -> Task<Result, Never> {
            if let validationTask, validationTask.isCancelled == false {
                return validationTask
            }

            self.lastResult = nil

            let task: Task<Result, Never> = Task { @MainActor [weak self, validatorBlock] in
                do {
                    try await self?.processBackOff()
                    try Task.checkCancellation()
                    let isValid = try await validatorBlock()
                    let result: Result = isValid ? .valid : .invalid
                    try Task.checkCancellation()
                    self?.processResult(result)
                    return result
                } catch {
                    if !Task.isCancelled {
                        self?.processResult(.error)
                    }
                    return .error
                }
            }

            validationTask = task
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
        private func processResult(_ result: Result)  {
            self.lastResult = result
            self.lastAttempt = self.date.now

            if (result == .error) {
                self.nextBackOff = if let last = self.nextBackOff {
                    min(last * 2, Self.maxBackfOff)
                } else {
                    Self.initialBackOff
                }
            } else {
                self.nextBackOff = nil
            }
        }

        /// Performs validation with a given block.
        /// - Parameter validatorBlock: The block performing the validation.
        /// - Returns: The result of the validation (`Result`).
        private class func doValidation(
            validatorBlock: (@Sendable () async throws -> Bool)?
        ) async -> Result {
            guard let validatorBlock else { return .error }
            do {
                return try await validatorBlock() ? .valid : .invalid
            } catch {
                AirshipLogger.error("Failed to validate \(error)")
                return .error
            }
        }
    }
}
