/* Copyright Airship and Contributors */

import Foundation
@_spi(AirshipImport) import AirshipCore
@_spi(AirshipInternal) import AirshipBasement

#if canImport(FoundationModels) && !os(tvOS)

import FoundationModels

/// Production `AirshipAI.Model` backed by Apple's on-device `SystemLanguageModel`.
///
/// Answers a single request per `respond` call — retry, timeout, and output
/// validation live in the framework's evaluator.
@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
final class DefaultOnDeviceModel: AirshipAI.Model {

    var availability: AirshipAI.Availability {
        Self.map(SystemLanguageModel.default.availability)
    }

    /// Streams availability as the on-device model changes state (e.g. finishes
    /// downloading, or Apple Intelligence is toggled in Settings). `SystemLanguageModel`
    /// is `@Observable`, so `AvailabilityObservation` tracks `availability` and re-emits
    /// on each change.
    var availabilityUpdates: AsyncStream<AirshipAI.Availability> {
        AvailabilityObservation.stream {
            Self.map(SystemLanguageModel.default.availability)
        }
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

    func respond(_ request: AirshipAI.Request) async throws -> AirshipJSON {
        // Guided generation constrains the model to the schema, so the response is
        // structurally guaranteed to conform — no code-fence stripping or JSON repair.
        let generationSchema = try request.schema.generationSchema()

        // Trim the context up front with tokenizer measurements when the OS can
        // measure — much cheaper than paying a full generation per dropped item.
        var request = request
        if #available(iOS 26.4, macOS 26.4, visionOS 26.4, *) {
            request = await Self.measuredTrim(request: request, schema: generationSchema)
        }

        // Backstop: the model rejects prompts that still exceed the window
        // (pre-26.4 runtimes, or measurement drift). Shrink the context one
        // lowest-priority item at a time until it fits.
        while true {
            try Task.checkCancellation()

            do {
                // A fresh session per call so an evaluator retry is an independent
                // judgment rather than a continuation of a failed turn's transcript.
                let session = LanguageModelSession(instructions: request.instructions)
                let response = try await session.respond(
                    to: request.prompt(),
                    schema: generationSchema
                )
                return response.content.airshipJSON
            } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
                guard let dropped = request.dropLowestPriorityContextItem() else {
                    throw AirshipErrors.error(
                        "DefaultOnDeviceModel: prompt exceeds the context window with no context left to drop"
                    )
                }
                AirshipLogger.trace("DefaultOnDeviceModel: prompt exceeded context window, dropped context item: \(dropped.content)")
            }
        }
    }

    /// Drops the lowest-priority context items until the measured token count of
    /// instructions + schema + prompt + context (plus a response reserve) fits the
    /// model's context window. Measurement failures fall back to the generation-time
    /// backstop in `respond`.
    @available(iOS 26.4, macOS 26.4, visionOS 26.4, *)
    private static func measuredTrim(
        request: AirshipAI.Request,
        schema: GenerationSchema
    ) async -> AirshipAI.Request {
        let model = SystemLanguageModel.default
        do {
            let instructionTokens = try await model.tokenCount(for: Instructions(request.instructions))
            let schemaTokens = try await model.tokenCount(for: schema)
            let fixedTokens = instructionTokens + schemaTokens + Self.responseTokenReserve

            var request = request
            while true {
                let promptTokens = try await model.tokenCount(for: request.prompt())
                let total = fixedTokens + promptTokens
                guard total > model.contextSize else {
                    return request
                }
                guard let dropped = request.dropLowestPriorityContextItem() else {
                    // Nothing left to drop yet the prompt still overflows — the fixed
                    // portion (instructions + schema + reserve) alone exceeds the window.
                    // Trimming can't help; let generation surface the authoritative error.
                    AirshipLogger.warn("DefaultOnDeviceModel: prompt measures \(total)/\(model.contextSize) tokens with no context left to drop — the instructions/schema alone exceed the context window")
                    return request
                }
                AirshipLogger.trace("DefaultOnDeviceModel: prompt measures \(total)/\(model.contextSize) tokens, dropped context item: \(dropped.content)")
            }
        } catch {
            AirshipLogger.debug("DefaultOnDeviceModel: token measurement failed (\(error)) — relying on generation-time trimming")
            return request
        }
    }
}

#endif
