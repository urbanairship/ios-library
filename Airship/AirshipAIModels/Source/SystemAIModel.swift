/* Copyright Airship and Contributors */

import Foundation
@_spi(AirshipImport) import AirshipCore
@_spi(AirshipInternal) import AirshipBasement

#if canImport(FoundationModels)
import FoundationModels

/// Production `AirshipAI.Model` backed by Apple's on-device `SystemLanguageModel`.
///
/// This is the only file in the SDK that imports FoundationModels.
@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
final class SystemAIModel: AirshipAI.Model {

    /// Total wall-clock budget for a response across all retry attempts. A backstop
    /// against a pathological hang, not a latency target — on timeout we fail open.
    private static let responseTimeout: TimeInterval = 30

    var availability: AirshipAI.Availability {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return .unavailable(reason: .deviceNotEligible)
            case .appleIntelligenceNotEnabled:
                return .unavailable(reason: .appleIntelligenceNotEnabled)
            case .modelNotReady:
                return .unavailable(reason: .modelNotReady)
            @unknown default:
                return .unavailable(reason: .unknown)
            }
        }
    }

    func respond(
        instructions: String,
        prompt: String,
        schema: AirshipAI.Schema
    ) async throws -> AirshipJSON {
        // Guided generation constrains the model to the schema, so the response is
        // structurally guaranteed to conform — no code-fence stripping or JSON repair.
        let generationSchema = try schema.generationSchema()

        return try await withThrowingTaskGroup(of: AirshipJSON.self) { group in
            group.addTask { [self] in
                try await withRetry {
                    // A fresh session per attempt so a retry is an independent judgment
                    // rather than a continuation of the previous (failed) turn's transcript.
                    let session = LanguageModelSession(instructions: instructions)
                    let response = try await session.respond(to: prompt, schema: generationSchema)
                    return response.content.airshipJSON
                }
            }
            group.addTask {
                try await Task.sleep(for: .seconds(Self.responseTimeout))
                throw AirshipErrors.error("SystemAIModel timed out after \(Self.responseTimeout)s")
            }
            defer { group.cancelAll() }
            return try await group.next()!
        }
    }

    private func withRetry<T: Sendable>(
        maxAttempts: Int = 3,
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        var lastError: (any Error)?
        for attempt in 1...maxAttempts {
            try Task.checkCancellation()
            do {
                return try await operation()
            } catch {
                lastError = error
                AirshipLogger.warn("SystemAIModel attempt \(attempt)/\(maxAttempts) failed: \(error)")
            }
        }
        throw lastError!
    }
}

// MARK: - AirshipAI.Schema -> GenerationSchema

@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
fileprivate extension AirshipAI.Schema {
    func generationSchema() throws -> GenerationSchema {
        let root = FieldType.object(fields: fields).dynamicSchema(name: "Result")
        return try GenerationSchema(root: root, dependencies: [])
    }
}

@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
fileprivate extension AirshipAI.Schema.FieldType {
    /// Builds the FoundationModels schema for this field type, recursing into nested
    /// objects and arrays. `name` disambiguates nested object schemas.
    func dynamicSchema(name: String) -> DynamicGenerationSchema {
        switch self {
        case .string: return DynamicGenerationSchema(type: String.self)
        case .boolean: return DynamicGenerationSchema(type: Bool.self)
        case .integer: return DynamicGenerationSchema(type: Int.self)
        case .number: return DynamicGenerationSchema(type: Double.self)
        case .object(let fields):
            let properties = fields.map { field in
                DynamicGenerationSchema.Property(
                    name: field.name,
                    description: field.description,
                    schema: field.type.dynamicSchema(name: "\(name)_\(field.name)"),
                    isOptional: !field.isRequired
                )
            }
            return DynamicGenerationSchema(name: name, properties: properties)
        case .array(let element):
            return DynamicGenerationSchema(arrayOf: element.dynamicSchema(name: "\(name)_element"))
        @unknown default:
            // A field type added in a newer Core than this model — should not happen in
            // practice; degrade to string.
            AirshipLogger.warn("SystemAIModel: unknown AirshipAI.Schema.FieldType, degrading to a string schema")
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
