/* Copyright Airship and Contributors */

import Foundation
@_spi(AirshipInternal) import AirshipBasement

extension AirshipAI {
    struct Evaluator {

        /// A hard ceiling on an evaluation's total wall-clock time — including every retry
        /// and delay between them — independent of whatever schedule `retryDecision` picks.
        /// A backstop against a pathological hang, not a latency target. Injectable so tests
        /// can dial it down instead of waiting on the real default.
        private let maxResponseTimeout: TimeInterval

        init(maxResponseTimeout: TimeInterval = 120) {
            self.maxResponseTimeout = maxResponseTimeout
        }

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
                let json = try await Self.withTimeout(maxResponseTimeout) {
                    try await Self.withRetry(model: model, usage: anyUsage, usageString: usage, maxDelay: maxResponseTimeout) {
                        attempts.update { $0 += 1 }
                        let json = try await model.respond(request)
                        // Reject non-conforming output inside the retry loop so another attempt
                        // can correct it. Wrapped so a model's retryDecision can tell a schema
                        // mismatch apart from a failure thrown by respond(_:) itself.
                        do {
                            try schema.validate(json)
                        } catch {
                            throw SchemaValidationError(underlyingError: error)
                        }
                        return json
                    }
                }
                AirshipLogger.trace("AI evaluate [\(usage)] completed in \(Date().timeIntervalSince(started))s")
                // Reported before decoding, so an output the feature can't decode is still
                // visible to whoever is watching — that's exactly when you want to see it.
                report(.completed(json))
                do {
                    let output: E.Output = try json.decode()
                    return .completed(output)
                } catch {
                    // Already reported above: a decode failure here is the feature's problem,
                    // not a second evaluation outcome.
                    AirshipLogger.warn("AI evaluation failed for \(usage): \(error)")
                    return .failed(error)
                }
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

        /// Races `operation` against `timeout`. On expiry the evaluation fails open at the
        /// call site.
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

        /// Runs `operation`, asking the model after each failure whether to retry (and
        /// after how long) or give up. The model's `retryDecision` picks the schedule;
        /// `withTimeout` above still caps the total time it's given to do so.
        private static func withRetry<T: Sendable>(
            model: any ModelProtocol,
            usage: AnyUsage,
            usageString: String,
            maxDelay: TimeInterval,
            operation: @Sendable () async throws -> T
        ) async throws -> T {
            var attempt = 0
            while true {
                attempt += 1
                try Task.checkCancellation()
                do {
                    return try await operation()
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    AirshipLogger.warn("AI evaluation attempt \(attempt) failed for \(usageString): \(error)")
                    switch model.retryDecision(usage: usage, error: error, attempt: attempt) {
                    case .fail:
                        throw error
                    case .retry(after: let delay):
                        if delay > 0 {
                            // `retryDecision` is customer-implementable; clamp so a non-finite
                            // or huge delay can't trap the UInt64 conversion below. Anything
                            // past `maxDelay` is cut off by the outer timeout regardless.
                            let clamped = delay.isFinite ? min(delay, maxDelay) : maxDelay
                            try await Task.sleep(nanoseconds: UInt64(clamped * 1_000_000_000))
                        }
                    }
                }
            }
        }
    }
}
