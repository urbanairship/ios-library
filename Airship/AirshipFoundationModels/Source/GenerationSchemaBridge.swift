/* Copyright Airship and Contributors */

import Foundation
@_spi(AirshipImport) import AirshipCore
@_spi(AirshipInternal) import AirshipBasement

// FoundationModels ships a tvOS stub where every symbol is unavailable, so `canImport`
// alone isn't enough to gate this file.
#if canImport(FoundationModels) && !os(tvOS)
import FoundationModels

// MARK: - AirshipJSONSchema -> GenerationSchema

@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
extension AirshipJSONSchema {
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
            // A value type added in a newer Core than this module — should not happen in
            // practice; degrade to string.
            AirshipLogger.warn("AirshipFoundationModels: unknown AirshipJSONSchema.ValueType, degrading to a string schema")
            return DynamicGenerationSchema(type: String.self)
        }
    }
}

// MARK: - GeneratedContent -> AirshipJSON

@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
extension GeneratedContent {
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
