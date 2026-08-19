/* Copyright Airship and Contributors */

public import Foundation
@_spi(AirshipImport) public import AirshipCore
@_spi(AirshipInternal) import AirshipBasement

// FoundationModels ships a tvOS stub where every symbol is unavailable, so `canImport`
// alone isn't enough to gate this file.
#if canImport(FoundationModels) && !os(tvOS)
public import FoundationModels

/// An `AirshipAI.ModelProtocol` backed by a Foundation Models `LanguageModel`.
///
/// Build one with ``backed(by:reasoningLevel:maxAttempts:responseTimeout:availability:)`` to
/// wrap any `LanguageModel` — Apple's on-device `SystemLanguageModel` or your own conformance
/// — or with ``privateCloudCompute(reasoningLevel:maxAttempts:responseTimeout:)`` for Apple's
/// Private Cloud Compute model:
///
///     Airship.ai.setModelResolver { _ in
///         .custom(AirshipFoundationModel.privateCloudCompute(reasoningLevel: .deep))
///     }
///
/// Requests use guided generation, so responses are structurally constrained to the
/// evaluation's schema. Like the SDK's built-in on-device model, this answers a single
/// request per `respond` call — retry, timeout, and output validation live in the
/// framework's evaluator.
///
/// - Note: Requires iOS 27. The SDK's built-in on-device model — used when no resolver is
///   set — works on iOS 26.
@available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
public struct AirshipFoundationModel<Backing: LanguageModel>: AirshipAI.ModelProtocol {

    /// The Foundation Models model that answers requests.
    public let model: Backing

    /// Reasoning effort requested from the model. Ignored by models that don't declare the
    /// `.reasoning` capability; `nil` leaves the level to the model's own default.
    public let reasoningLevel: ContextOptions.ReasoningLevel?

    public let maxAttempts: Int
    public let responseTimeout: TimeInterval

    private let availabilityProvider: @Sendable () -> AirshipAI.Availability
    private let availabilityStreamProvider: @Sendable () -> AsyncStream<AirshipAI.Availability>

    public var availability: AirshipAI.Availability {
        availabilityProvider()
    }

    public var availabilityUpdates: AsyncStream<AirshipAI.Availability> {
        availabilityStreamProvider()
    }

    init(
        model: Backing,
        reasoningLevel: ContextOptions.ReasoningLevel?,
        maxAttempts: Int,
        responseTimeout: TimeInterval,
        availabilityProvider: @escaping @Sendable () -> AirshipAI.Availability,
        availabilityStreamProvider: @escaping @Sendable () -> AsyncStream<AirshipAI.Availability>
    ) {
        self.model = model
        self.reasoningLevel = reasoningLevel
        self.maxAttempts = maxAttempts
        self.responseTimeout = responseTimeout
        self.availabilityProvider = availabilityProvider
        self.availabilityStreamProvider = availabilityStreamProvider
    }

    /// Wraps any Foundation Models `LanguageModel` as an Airship AI model.
    ///
    ///     Airship.ai.setModelResolver { _ in
    ///         .custom(AirshipFoundationModel.backed(by: SystemLanguageModel.default))
    ///     }
    ///
    /// `LanguageModel` requires only `capabilities` and `executorConfiguration` —
    /// availability lives on the concrete types as unrelated nested enums
    /// (`SystemLanguageModel.Availability`, `PrivateCloudComputeLanguageModel.Availability`),
    /// so there is nothing generic to read. Pass `availability` to map your backing model's
    /// state onto `AirshipAI.Availability`; omit it and the model always reports
    /// `.available`, meaning Airship attempts every evaluation and treats a thrown response
    /// as a failure.
    ///
    ///     AirshipFoundationModel.backed(by: SystemLanguageModel.default) { model in
    ///         switch model.availability {
    ///         case .available: return .available
    ///         case .unavailable: return .unavailable(reason: .missingModel)
    ///         }
    ///     }
    ///
    /// - Parameters:
    ///   - model: the model to run requests against.
    ///   - reasoningLevel: reasoning effort for models that declare `.reasoning`. Defaults
    ///     to `nil`, which leaves the level to the model.
    ///   - maxAttempts: attempts (including the first) the evaluator makes before failing.
    ///   - responseTimeout: total wall-clock budget across all attempts. Raise it for a
    ///     backend slower than an on-device model.
    ///   - availability: maps `model` to its current availability. Read fresh before every
    ///     evaluation, and evaluated under Observation tracking to drive
    ///     `availabilityUpdates` — so when the backing model is `@Observable` (as Apple's
    ///     are), availability changes are published without any further work.
    public static func backed(
        by model: Backing,
        reasoningLevel: ContextOptions.ReasoningLevel? = nil,
        maxAttempts: Int = 3,
        responseTimeout: TimeInterval = 30,
        availability: (@Sendable (Backing) -> AirshipAI.Availability)? = nil
    ) -> Self {
        guard let availability else {
            return AirshipFoundationModel(
                model: model,
                reasoningLevel: reasoningLevel,
                maxAttempts: maxAttempts,
                responseTimeout: responseTimeout,
                availabilityProvider: { .available },
                // Nothing to observe, so emit once and finish — the same contract as
                // `AirshipAI.ModelProtocol`'s default implementation.
                availabilityStreamProvider: {
                    AsyncStream { continuation in
                        continuation.yield(.available)
                        continuation.finish()
                    }
                }
            )
        }

        return AirshipFoundationModel(
            model: model,
            reasoningLevel: reasoningLevel,
            maxAttempts: maxAttempts,
            responseTimeout: responseTimeout,
            availabilityProvider: { availability(model) },
            availabilityStreamProvider: {
                AvailabilityObservation.stream { availability(model) }
            }
        )
    }

    public func respond(_ request: AirshipAI.Request) async throws -> AirshipJSON {
        // Guided generation is what makes the response structurally conform to the schema.
        // Without it there is nothing to parse reliably, so fail rather than free-generate.
        guard model.capabilities.contains(.guidedGeneration) else {
            throw AirshipErrors.error(
                "AirshipFoundationModel: \(Backing.self) does not support guided generation"
            )
        }

        let generationSchema = try request.schema.generationSchema()

        // Sending a reasoning level to a model without the capability is an error — drop it
        // instead of failing an evaluation over a hint the model can't use.
        let contextOptions = ContextOptions(
            includeSchemaInPrompt: true,
            reasoningLevel: model.capabilities.contains(.reasoning) ? reasoningLevel : nil
        )

        // The `LanguageModel` protocol exposes no tokenizer, so unlike the on-device model
        // this can't measure the prompt up front. Shrink the context one lowest-priority
        // item at a time whenever the model reports an overflow.
        var request = request
        while true {
            try Task.checkCancellation()

            do {
                // A fresh session per call so an evaluator retry is an independent judgment
                // rather than a continuation of a failed turn's transcript.
                let session = LanguageModelSession(
                    model: model,
                    instructions: Instructions(request.instructions)
                )

                let response = try await session.respond(
                    to: Prompt(request.prompt()),
                    schema: generationSchema,
                    contextOptions: contextOptions
                )
                return response.content.airshipJSON
            } catch LanguageModelError.contextSizeExceeded(let context) {
                guard let dropped = request.dropLowestPriorityContextItem() else {
                    throw AirshipErrors.error(
                        "AirshipFoundationModel: prompt exceeds the context window with no context left to drop"
                    )
                }
                AirshipLogger.trace("AirshipFoundationModel: prompt measures \(context.tokenCount)/\(context.contextSize) tokens, dropped context item: \(dropped.content)")
            }
        }
    }
}

// MARK: - Private Cloud Compute

@available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension AirshipFoundationModel where Backing == PrivateCloudComputeLanguageModel {

    /// An `AirshipAI.ModelProtocol` backed by Apple's Private Cloud Compute model.
    ///
    /// A larger model than the on-device one, so it handles harder judgments, at the cost of
    /// a network round trip and a per-app quota. Prompts and context leave the device — they
    /// go to Apple's Private Cloud Compute, never to Airship.
    ///
    ///     Airship.ai.setModelResolver { _ in
    ///         .custom(AirshipFoundationModel.privateCloudCompute(reasoningLevel: .deep))
    ///     }
    ///
    /// Availability tracks `PrivateCloudComputeLanguageModel.availability` live, so an
    /// evaluation is skipped while the device is ineligible or the system isn't ready.
    ///
    /// - Parameters:
    ///   - reasoningLevel: how much the model should reason before answering. Defaults to
    ///     `.moderate`; `.light` trades quality for latency, `.deep` the reverse.
    ///   - maxAttempts: attempts (including the first) the evaluator makes before failing.
    ///   - responseTimeout: total wall-clock budget across all attempts. Defaults to 60
    ///     seconds — twice the on-device budget, since each attempt is a network round trip.
    public static func privateCloudCompute(
        reasoningLevel: ContextOptions.ReasoningLevel? = .moderate,
        maxAttempts: Int = 3,
        responseTimeout: TimeInterval = 60
    ) -> Self {
        let model = PrivateCloudComputeLanguageModel()
        return AirshipFoundationModel(
            model: model,
            reasoningLevel: reasoningLevel,
            maxAttempts: maxAttempts,
            responseTimeout: responseTimeout,
            availabilityProvider: { map(model.availability) },
            // `PrivateCloudComputeLanguageModel` is `@Observable`, so availability updates
            // publish themselves once read under observation tracking.
            availabilityStreamProvider: {
                AvailabilityObservation.stream { map(model.availability) }
            }
        )
    }

    private static func map(
        _ availability: PrivateCloudComputeLanguageModel.Availability
    ) -> AirshipAI.Availability {
        switch availability {
        case .available:
            return .available
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return .unavailable(reason: .deviceNotEligible)
            case .systemNotReady:
                return .unavailable(reason: .missingModel)
            @unknown default:
                return .unavailable(reason: .other(String(describing: reason)))
            }
        }
    }
}

#endif
