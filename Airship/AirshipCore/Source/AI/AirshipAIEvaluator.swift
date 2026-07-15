/* Copyright Airship and Contributors */

import Foundation
@_spi(AirshipInternal) import AirshipBasement

extension AirshipAI {
    struct Evaluator {

        func evaluate<E: Evaluation>(
            _ evaluation: E,
            model: any Model,
            context: Context
        ) async -> Result<E.Output> {
            guard case .available = model.availability else {
                return .skipped(reason: "On-device model unavailable")
            }

            let schema = evaluation.schema
            let instructions = evaluation.instructions()
            let prompt = evaluation.prompt()
            let usage = evaluation.usage.rawValue

            AirshipLogger.debug("AI evaluate [\(usage)] instructions:\n\(instructions)\n\nschema:\n\(schema.instruction)\n\nprompt:\n\(prompt)\n\ncontext:\n\(context.render() ?? "none")")

            do {
                let json = try await Self.withTimeout(model.responseTimeout) {
                    try await Self.withRetry(maxAttempts: model.maxAttempts, usage: usage) {
                        let json = try await model.respond(
                            instructions: instructions,
                            prompt: prompt,
                            context: context,
                            schema: schema
                        )
                        // Reject non-conforming output inside the retry loop so
                        // another attempt can correct it.
                        try schema.validate(json)
                        return json
                    }
                }
                AirshipLogger.debug("AI evaluate [\(usage)] response:\n\(json)")
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
            var lastError: (any Error)?
            for attempt in 1...attempts {
                try Task.checkCancellation()
                do {
                    return try await operation()
                } catch {
                    lastError = error
                    AirshipLogger.warn("AI evaluation attempt \(attempt)/\(attempts) failed for \(usage): \(error)")
                }
            }
            throw lastError!
        }
    }
}
