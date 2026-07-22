/* Copyright Airship and Contributors */

import Foundation
@_spi(AirshipImport) import AirshipCore
@_spi(AirshipInternal) import AirshipBasement

#if canImport(FoundationModels)
import FoundationModels

/// Lifetime flag for an availability observation chain, flipped when the stream is torn
/// down so the self-re-arming `withObservationTracking` loop stops.
@MainActor
private final class ObservationToken {
    var isCancelled = false
}

/// Production `AirshipAI.Model` backed by Apple's on-device `SystemLanguageModel`.
///
/// Answers a single request per `respond` call — retry, timeout, and output
/// validation live in the framework's evaluator.
///
/// This is the only file in the SDK that imports FoundationModels.
@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
final class SystemAIModel: AirshipAI.Model {

    let maxAttempts: Int = 3
    let responseTimeout: TimeInterval = 30

    var availability: AirshipAI.Availability {
        Self.map(SystemLanguageModel.default.availability)
    }

    /// Streams availability as the on-device model changes state (e.g. finishes
    /// downloading, or Apple Intelligence is toggled in Settings). `SystemLanguageModel`
    /// is `@Observable`, so we track `availability` and re-emit on each change; the chain
    /// re-registers itself after every change and stops once the stream is torn down.
    var availabilityUpdates: AsyncStream<AirshipAI.Availability> {
        AsyncStream { continuation in
            let token = ObservationToken()
            Task { @MainActor in
                Self.observeAvailability(token: token, continuation: continuation)
            }
            continuation.onTermination = { _ in
                Task { @MainActor in token.isCancelled = true }
            }
        }
    }

    /// Reads the current availability under observation tracking and yields it, then
    /// re-arms itself when the tracked value changes. A no-op once `token` is cancelled.
    @MainActor
    private static func observeAvailability(
        token: ObservationToken,
        continuation: AsyncStream<AirshipAI.Availability>.Continuation
    ) {
        guard !token.isCancelled else { return }

        let current = withObservationTracking {
            Self.map(SystemLanguageModel.default.availability)
        } onChange: {
            // Fires just before the value changes; re-read on the next hop so we
            // observe the new value and re-establish tracking.
            Task { @MainActor in
                Self.observeAvailability(token: token, continuation: continuation)
            }
        }
        continuation.yield(current)
    }

    private static func map(
        _ availability: SystemLanguageModel.Availability
    ) -> AirshipAI.Availability {
        switch availability {
        case .available:
            return .available
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return .unavailable(reason: .deviceNotEligible)
            case .appleIntelligenceNotEnabled:
                return .unavailable(reason: .notEnabled)
            case .modelNotReady:
                return .unavailable(reason: .missingModel)
            @unknown default:
                return .unavailable(reason: .other(String(describing: reason)))
            }
        }
    }

    /// Output tokens share the context window with the input — reserve room for the
    /// schema-constrained response when measuring whether the prompt fits.
    private static let responseTokenReserve: Int = 512

    func respond(
        instructions: String,
        prompt: String,
        context: AirshipAI.Context,
        schema: AirshipJSONSchema
    ) async throws -> AirshipJSON {
        // Guided generation constrains the model to the schema, so the response is
        // structurally guaranteed to conform — no code-fence stripping or JSON repair.
        let generationSchema = try schema.generationSchema()

        // Trim the context up front with tokenizer measurements when the OS can
        // measure — much cheaper than paying a full generation per dropped item.
        var context = context
        if #available(iOS 26.4, macOS 26.4, visionOS 26.4, *) {
            context = await Self.measuredTrim(
                context: context,
                instructions: instructions,
                prompt: prompt,
                schema: generationSchema
            )
        }

        // Backstop: the model rejects prompts that still exceed the window
        // (pre-26.4 runtimes, or measurement drift). Shrink the context one
        // lowest-priority item at a time until it fits.
        while true {
            try Task.checkCancellation()

            do {
                // A fresh session per call so an evaluator retry is an independent
                // judgment rather than a continuation of a failed turn's transcript.
                let session = LanguageModelSession(instructions: instructions)
                let response = try await session.respond(
                    to: Self.fullPrompt(prompt: prompt, context: context),
                    schema: generationSchema
                )
                return response.content.airshipJSON
            } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
                guard let reduced = context.droppingLowestPriorityItem() else {
                    throw AirshipErrors.error(
                        "SystemAIModel: prompt exceeds the context window with no context left to drop"
                    )
                }
                AirshipLogger.debug("SystemAIModel: prompt exceeded context window, dropping a low-priority context item")
                context = reduced
            }
        }
    }

    private static func fullPrompt(prompt: String, context: AirshipAI.Context) -> String {
        guard let rendered = context.render() else { return prompt }
        return "\(prompt)\n\(rendered)"
    }

    /// Drops the lowest-priority context items until the measured token count of
    /// instructions + schema + prompt + context (plus a response reserve) fits the
    /// model's context window. Measurement failures fall back to the generation-time
    /// backstop in `respond`.
    @available(iOS 26.4, macOS 26.4, visionOS 26.4, *)
    private static func measuredTrim(
        context: AirshipAI.Context,
        instructions: String,
        prompt: String,
        schema: GenerationSchema
    ) async -> AirshipAI.Context {
        let model = SystemLanguageModel.default
        do {
            let instructionTokens = try await model.tokenCount(for: Instructions(instructions))
            let schemaTokens = try await model.tokenCount(for: schema)
            let fixedTokens = instructionTokens + schemaTokens + Self.responseTokenReserve

            var context = context
            while true {
                let promptTokens = try await model.tokenCount(
                    for: fullPrompt(prompt: prompt, context: context)
                )
                let total = fixedTokens + promptTokens
                guard total > model.contextSize else {
                    return context
                }
                guard let reduced = context.droppingLowestPriorityItem() else {
                    // Nothing left to drop yet the prompt still overflows — the fixed
                    // portion (instructions + schema + reserve) alone exceeds the window.
                    // Trimming can't help; let generation surface the authoritative error.
                    AirshipLogger.warn("SystemAIModel: prompt measures \(total)/\(model.contextSize) tokens with no context left to drop — the instructions/schema alone exceed the context window")
                    return context
                }
                AirshipLogger.debug("SystemAIModel: prompt measures \(total)/\(model.contextSize) tokens, dropping a low-priority context item")
                context = reduced
            }
        } catch {
            AirshipLogger.debug("SystemAIModel: token measurement failed (\(error)) — relying on generation-time trimming")
            return context
        }
    }
}

// MARK: - AirshipJSONSchema -> GenerationSchema

@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
fileprivate extension AirshipJSONSchema {
    func generationSchema() throws -> GenerationSchema {
        return try GenerationSchema(
            root: dynamicSchema(name: "Result"),
            dependencies: []
        )
    }

    /// Builds the FoundationModels schema for this node, recursing into nested
    /// objects and arrays. `name` disambiguates nested object schemas.
    func dynamicSchema(name: String) -> DynamicGenerationSchema {
        switch type {
        case .string(let info):
            guard let choices = info.choices else {
                return DynamicGenerationSchema(type: String.self)
            }
            // Guided generation constrains output to the choices — the model cannot
            // produce an out-of-vocabulary value.
            return DynamicGenerationSchema(name: name, description: self.description, anyOf: choices)
        case .boolean: return DynamicGenerationSchema(type: Bool.self)
        case .integer: return DynamicGenerationSchema(type: Int.self)
        case .number: return DynamicGenerationSchema(type: Double.self)
        case .object(let info):
            let schemaProperties = (info.properties ?? [:])
                .map { (propertyName, property) in
                    DynamicGenerationSchema.Property(
                        name: propertyName,
                        description: property.description,
                        schema: property.dynamicSchema(name: "\(name)_\(propertyName)"),
                        isOptional: !(info.required?.contains(propertyName) ?? false)
                    )
                }
            return DynamicGenerationSchema(name: name, description: self.description, properties: schemaProperties)
        case .array(let info):
            return DynamicGenerationSchema(arrayOf: info.items.dynamicSchema(name: "\(name)_element"))
        @unknown default:
            // A value type added in a newer Core than this model — should not happen in
            // practice; degrade to string.
            AirshipLogger.warn("SystemAIModel: unknown AirshipJSONSchema.ValueType, degrading to a string schema")
            return DynamicGenerationSchema(type: String.self)
        }
    }
}

// MARK: - GeneratedContent -> AirshipJSON

@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
fileprivate extension GeneratedContent {
    var airshipJSON: AirshipJSON {
        switch kind {
        case .null: return .null
        case .bool(let value): return .bool(value)
        case .number(let value): return .number(value)
        case .string(let value): return .string(value)
        case .array(let items): return .array(items.map(\.airshipJSON))
        case .structure(let properties, _): return .object(properties.mapValues(\.airshipJSON))
        @unknown default: return .null
        }
    }
}

#endif
