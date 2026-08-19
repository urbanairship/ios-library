/* Copyright Airship and Contributors */

import Foundation
@_spi(AirshipInternal) import AirshipBasement

extension AirshipAI {
    struct Evaluator {

        func evaluate<E: Evaluation>(
            _ evaluation: E,
            model: any ModelProtocol,
            context: Context
        ) async -> Result<E.Output> {
            guard case .available = model.availability else {
                return .skipped(reason: "Model unavailable")
            }

            let schema = evaluation.schema
            let instructions = evaluation.instructions()
            let usage = evaluation.usage.rawValue

            let request = AirshipAI.Request(
                instructions: instructions,
                schema: schema,
                context: context,
                render: evaluation.prompt(context:)
            )

            AirshipLogger.trace("AI evaluate [\(usage)] instructions:\n\(instructions)\n\nschema:\n\(schema)\n\nprompt:\n\(request.prompt())\n\ncontext:\n\(context)")

            do {
                let json = try await Self.withTimeout(model.responseTimeout) {
                    try await Self.withRetry(maxAttempts: model.maxAttempts, usage: usage) {
                        let json = try await model.respond(request)
                        // Reject non-conforming output inside the retry loop so
                        // another attempt can correct it.
                        try schema.validate(json)
                        return json
                    }
                }
                AirshipLogger.trace("AI evaluate [\(usage)] response:\n\(json)")
                let output: E.Output = try json.decode()
                return .completed(output)
            } catch {
                AirshipLogger.warn("AI evaluation failed for \(usage): \(error)")
                return .failed(error)
            }
        }

        /// Races `operation` against a wall-clock budget. A backstop against a
        /// pathological hang, not a latency target — on expiry the evaluation fails
        /// open at the call site.
        private static func withTimeout<T: Sendable>(
            _ timeout: TimeInterval,
            operation: @escaping @Sendable () async throws -> T
        ) async throws -> T {
            try await withThrowingTaskGroup(of: T.self) { group in
                group.addTask {
                    try await operation()
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    throw AirshipErrors.error("AI evaluation timed out after \(timeout)s")
                }
                defer { group.cancelAll() }
                return try await group.next()!
            }
        }

        private static func withRetry<T: Sendable>(
            maxAttempts: Int,
            usage: String,
            operation: @Sendable () async throws -> T
        ) async throws -> T {
            let attempts = max(1, maxAttempts)
            for attempt in 1...attempts {
                try Task.checkCancellation()
                do {
                    return try await operation()
                } catch is CancellationError {
                    // Cancellation (e.g. the timeout firing) is terminal — propagate it
                    // rather than burning a retry on it.
                    throw CancellationError()
                } catch {
                    AirshipLogger.warn("AI evaluation attempt \(attempt)/\(attempts) failed for \(usage): \(error)")
                    if attempt == attempts { throw error }
                }
            }
            preconditionFailure("withRetry exhausted — unreachable")
        }
    }
}
