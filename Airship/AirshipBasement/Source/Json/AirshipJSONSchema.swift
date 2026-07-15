/* Copyright Airship and Contributors */

import Foundation

/// Describes the structured JSON output an on-device AI evaluation expects from the model.
///
/// Backend-agnostic — exposes no Apple FoundationModels types. Lives in AirshipBasement so
/// payload-driven features (e.g. scene layouts) can decode a schema without AirshipCore.
///
/// A schema is a recursive type node using JSON Schema conventions, so the output can be
/// an object, an array, or a single scalar value:
/// ```json
/// {
///   "type": "object",
///   "properties": {
///     "result": { "type": "string", "enum": ["a", "b"], "description": "..." },
///     "reason": { "type": "string" }
///   },
///   "required": ["result"]
/// }
/// { "type": "string", "enum": ["a", "b", "c"] }
/// { "type": "array", "items": { "type": "string" } }
/// ```
/// Properties are unordered. Per JSON Schema, a property is optional
/// unless listed in `required`.
///
/// Each value type carries an info struct so future constraints (`minimum`, `pattern`,
/// `minItems`, ...) are additive rather than case-signature changes.
public struct AirshipJSONSchema: Sendable, Equatable {

    public indirect enum ValueType: Sendable, Equatable {
        case string(StringInfo)
        case boolean
        case integer(NumberInfo)
        case number(NumberInfo)
        case object(ObjectInfo)
        case array(ArrayInfo)
    }

    /// String constraints.
    public struct StringInfo: Sendable, Equatable {
        /// Constrains the value to one of these choices (JSON Schema `enum`). With
        /// guided generation the model cannot produce a value outside the choices;
        /// validation rejects out-of-vocabulary values from models that can.
        public var choices: [String]?

        public init(choices: [String]? = nil) {
            self.choices = choices
        }
    }

    /// Integer/number constraints. Currently empty — reserved for `minimum`,
    /// `maximum`, `multipleOf`, ...
    public struct NumberInfo: Sendable, Equatable {
        public init() {}
    }

    /// Object shape.
    public struct ObjectInfo: Sendable, Equatable {
        /// Named properties.
        public var properties: [String: AirshipJSONSchema]
        /// Property names that must be present. Per JSON Schema, anything not listed
        /// is optional.
        public var required: Set<String>

        public init(
            properties: [String: AirshipJSONSchema],
            required: Set<String> = []
        ) {
            self.properties = properties
            self.required = required
        }
    }

    /// Array shape.
    public struct ArrayInfo: Sendable, Equatable {
        /// Every element conforms to this schema.
        public var items: AirshipJSONSchema

        public init(items: AirshipJSONSchema) {
            self.items = items
        }
    }

    /// The expected shape of the value.
    public let type: ValueType

    /// Optional natural-language description, surfaced to the model.
    public let description: String?

    public init(type: ValueType, description: String? = nil) {
        self.type = type
        self.description = description
    }
}

// MARK: - Convenience constructors

extension AirshipJSONSchema {

    public static func string(
        choices: [String]? = nil,
        description: String? = nil
    ) -> AirshipJSONSchema {
        .init(type: .string(.init(choices: choices)), description: description)
    }

    public static func boolean(description: String? = nil) -> AirshipJSONSchema {
        .init(type: .boolean, description: description)
    }

    public static func integer(description: String? = nil) -> AirshipJSONSchema {
        .init(type: .integer(.init()), description: description)
    }

    public static func number(description: String? = nil) -> AirshipJSONSchema {
        .init(type: .number(.init()), description: description)
    }

    public static func object(
        properties: [String: AirshipJSONSchema],
        required: Set<String> = [],
        description: String? = nil
    ) -> AirshipJSONSchema {
        .init(
            type: .object(.init(properties: properties, required: required)),
            description: description
        )
    }

    public static func array(
        items: AirshipJSONSchema,
        description: String? = nil
    ) -> AirshipJSONSchema {
        .init(type: .array(.init(items: items)), description: description)
    }
}

// MARK: - Codable

extension AirshipJSONSchema: Codable {

    enum CodingKeys: String, CodingKey {
        case type
        case description
        case properties
        case required
        case items
        case choices = "enum"
    }

    private enum RawType: String, Codable {
        case string
        case boolean
        case integer
        case number
        case object
        case array
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)

        switch try container.decode(RawType.self, forKey: .type) {
        case .string:
            self.type = .string(
                .init(choices: try container.decodeIfPresent([String].self, forKey: .choices))
            )
        case .boolean:
            self.type = .boolean
        case .integer:
            self.type = .integer(.init())
        case .number:
            self.type = .number(.init())
        case .object:
            self.type = .object(
                .init(
                    properties: try container.decode([String: AirshipJSONSchema].self, forKey: .properties),
                    required: Set(try container.decodeIfPresent([String].self, forKey: .required) ?? [])
                )
            )
        case .array:
            self.type = .array(
                .init(items: try container.decode(AirshipJSONSchema.self, forKey: .items))
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(description, forKey: .description)

        switch type {
        case .string(let info):
            try container.encode(RawType.string, forKey: .type)
            try container.encodeIfPresent(info.choices, forKey: .choices)
        case .boolean:
            try container.encode(RawType.boolean, forKey: .type)
        case .integer:
            try container.encode(RawType.integer, forKey: .type)
        case .number:
            try container.encode(RawType.number, forKey: .type)
        case .object(let info):
            try container.encode(RawType.object, forKey: .type)
            try container.encode(info.properties, forKey: .properties)
            if !info.required.isEmpty {
                try container.encode(info.required, forKey: .required)
            }
        case .array(let info):
            try container.encode(RawType.array, forKey: .type)
            try container.encode(info.items, forKey: .items)
        }
    }
}

// MARK: - Schema instruction helper

extension AirshipJSONSchema {
    /// A natural-language description of the expected JSON shape, ready to append
    /// to model instructions. Model implementors can include this in the system
    /// prompt to constrain output without guided generation.
    public var instruction: String {
        switch type {
        case .object(let info):
            let lines = info.properties
                .map { "  \(Self.describe(name: $0.key, schema: $0.value, isRequired: info.required.contains($0.key)))" }
            return """
            *Return the data in JSON format. Do not use markdown backticks or fences.*
            The response must start with { and end with }. Fields:
            {
            \(lines.joined(separator: ",\n"))
            }
            """
        default:
            return """
            *Return the data in JSON format. Do not use markdown backticks or fences.*
            The response must be a single JSON value: \(Self.describe(schema: self)).
            """
        }
    }

    /// Renders a property as `"name": <type> (required|optional) — description`.
    private static func describe(name: String, schema: AirshipJSONSchema, isRequired: Bool) -> String {
        let requirement = isRequired ? "required" : "optional"
        let description = schema.description.map { " — \($0)" } ?? ""
        return "\"\(name)\": \(describe(schema: schema)) (\(requirement))\(description)"
    }

    /// Renders a schema node, recursing into nested objects and arrays.
    private static func describe(schema: AirshipJSONSchema) -> String {
        switch schema.type {
        case .string(let info):
            guard let choices = info.choices else { return "string" }
            let rendered = choices.map { "\"\($0)\"" }.joined(separator: ", ")
            return "string, exactly one of: \(rendered)"
        case .boolean: return "boolean"
        case .integer: return "integer"
        case .number: return "number"
        case .object(let info):
            let inner = info.properties
                .map { describe(name: $0.key, schema: $0.value, isRequired: info.required.contains($0.key)) }
                .joined(separator: ", ")
            return "{ \(inner) }"
        case .array(let info):
            return "array of \(describe(schema: info.items))"
        }
    }
}

// MARK: - Schema validation

extension AirshipJSONSchema {
    /// Validates that `json` conforms to this schema.
    ///
    /// Extra keys not described by the schema are ignored. Optional properties may be
    /// absent or null.
    ///
    /// - Throws: an error describing the first violation; returns normally if valid.
    public func validate(_ json: AirshipJSON) throws {
        try Self.validate(json, against: self, path: "$")
    }

    private static func validate(
        _ value: AirshipJSON,
        against schema: AirshipJSONSchema,
        path: String
    ) throws {
        switch schema.type {
        case .string(let info):
            guard let string = value.string else { throw typeError(path, "string", value) }
            if let choices = info.choices, !choices.contains(string) {
                throw AirshipErrors.error(
                    "Schema validation: '\(string)' at '\(path)' is not one of \(choices)"
                )
            }
        case .boolean:
            guard value.isBool else { throw typeError(path, "boolean", value) }
        case .integer:
            guard let number = value.number, number.rounded() == number else {
                throw typeError(path, "integer", value)
            }
        case .number:
            guard value.isNumber else { throw typeError(path, "number", value) }
        case .object(let info):
            guard let object = value.object else { throw typeError(path, "object", value) }
            for (name, property) in info.properties {
                let child = object[name]
                if child == nil || child == AirshipJSON.null {
                    if info.required.contains(name) {
                        throw AirshipErrors.error(
                            "Schema validation: missing required property '\(path).\(name)'"
                        )
                    }
                    continue
                }
                try validate(child!, against: property, path: "\(path).\(name)")
            }
        case .array(let info):
            guard let array = value.array else { throw typeError(path, "array", value) }
            for (index, item) in array.enumerated() {
                try validate(item, against: info.items, path: "\(path)[\(index)]")
            }
        }
    }

    private static func typeError(_ path: String, _ expected: String, _ value: AirshipJSON) -> any Error {
        AirshipErrors.error("Schema validation: expected \(expected) at '\(path)'")
    }
}
