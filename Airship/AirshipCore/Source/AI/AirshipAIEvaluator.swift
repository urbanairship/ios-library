/* Copyright Airship and Contributors */

import Foundation
@_spi(AirshipInternal) import AirshipBasement

extension AirshipAI {
    struct Evaluator {

        func evaluate<E: Evaluation>(
            _ evaluation: E,
            model: any ModelProtocol,
            context: Context,
            observer: AirshipAI.EvaluationObserver? = nil
        ) async -> Result<E.Output> {
            let schema = evaluation.schema
            let instructions = evaluation.instructions()
            let usage = evaluation.usage.rawValue
            let anyUsage = AnyUsage(rawValue: usage)

            let request = AirshipAI.Request(
                instructions: instructions,
                schema: schema,
                context: context,
                render: evaluation.prompt(context:)
            )

            guard case .available = model.availability else {
                // Reported like any other outcome: a model that never runs is the common
                // case in the field, and the one an observer most wants to know about.
                Self.report(
                    to: observer,
                    AirshipAI.EvaluationRecord(
                        usage: anyUsage,
                        request: request,
                        outcome: .skipped(reason: "Model unavailable"),
                        duration: 0,
                        attempts: 0
                    )
                )
                return .skipped(reason: "Model unavailable")
            }

            // Metadata only, deliberately. Nothing that goes to the model or comes back from
            // it is logged: not the instructions, the schema, the rendered prompt, the
            // context, or the response. An evaluation's inputs and outputs exist for the
            // duration of the call and leave it only through `setEvaluationObserver(_:)`,
            // which the app has to register. That keeps the boundary somewhere a reader can
            // see rather than spread across log levels and privacy annotations.
            AirshipLogger.trace("AI evaluate [\(usage)] starting, context items: \(context.items.count)")

            let started = Date()
            let attempts = AirshipAtomicValue(0)

            func report(_ outcome: AirshipAI.EvaluationRecord.Outcome) {
                Self.report(
                    to: observer,
                    AirshipAI.EvaluationRecord(
                        usage: anyUsage,
                        request: request,
                        outcome: outcome,
                        duration: Date().timeIntervalSince(started),
                        attempts: attempts.value
                    )
                )
            }

            do {
                let json = try await Self.withTimeout(model.responseTimeout) {
                    try await Self.withRetry(maxAttempts: model.maxAttempts, usage: usage) {
                        attempts.update { $0 += 1 }
                        let json = try await model.respond(request)
                        // Reject non-conforming output inside the retry loop so
                        // another attempt can correct it.
                        try schema.validate(json)
                        return json
                    }
                }
                AirshipLogger.trace("AI evaluate [\(usage)] completed in \(Date().timeIntervalSince(started))s")
                // Reported before decoding, so an output the feature can't decode is still
                // visible to whoever is watching — that's exactly when you want to see it.
                report(.completed(json))
                let output: E.Output = try json.decode()
                return .completed(output)
            } catch {
                AirshipLogger.warn("AI evaluation failed for \(usage): \(error)")
                report(.failed(error))
                return .failed(error)
            }
        }


        /// Hands a finished evaluation to the observer on a task of its own.
        ///
        /// Detached so an observer that blocks — or one that reaches back into the SDK —
        /// can't delay the result reaching the feature that asked for it. Deliberately not
        /// main-actor: reporting is background work, and putting it on the main actor would
        /// let a slow observer stall the UI.
        private static func report(
            to observer: AirshipAI.EvaluationObserver?,
            _ record: AirshipAI.EvaluationRecord
        ) {
            guard let observer else { return }
            Task {
                observer(record)
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
