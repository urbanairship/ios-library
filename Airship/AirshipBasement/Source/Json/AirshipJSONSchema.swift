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
        /// Named properties, or `nil` when the schema specifies none (an object with no
        /// declared property constraints — per JSON Schema, any properties are allowed).
        public var properties: [String: AirshipJSONSchema]?
        /// Property names that must be present, in declaration order, or `nil` when the
        /// schema specifies none. An array (not a set) so the order round-trips.
        public var required: [String]?

        public init(
            properties: [String: AirshipJSONSchema]? = nil,
            required: [String]? = nil
        ) {
            self.properties = properties
            self.required = required
        }
    }

    /// Array shape.
    public struct ArrayInfo: Sendable, Equatable {
        /// Every element conforms to this schema. Tuple (positional) `items` is not
        /// supported — the on-device model can't guarantee positional output.
        public var items: AirshipJSONSchema

        public init(items: AirshipJSONSchema) {
            self.items = items
        }
    }

    /// The expected shape of the value.
    public let type: ValueType

    /// Optional natural-language description, surfaced to the model.
    public let description: String?

    /// JSON Schema extension keywords (`x-*`, the spec's vendor-extension convention)
    /// carried verbatim from the payload. Kept as opaque JSON so new extensions round-trip
    /// without decoder changes; consumers interpret whichever keys they care about.
    /// `validate` and guided-generation ignore these — they're metadata for other consumers.
    public let extensions: [String: AirshipJSON]

    public init(
        type: ValueType,
        description: String? = nil,
        extensions: [String: AirshipJSON] = [:]
    ) {
        self.type = type
        self.description = description
        // Same invariant the decoder enforces: only `x-*` keys live here. Keeps encode from
        // ever writing a key that collides with a real schema keyword (`type`, `enum`, ...).
        self.extensions = extensions.filter { $0.key.hasPrefix(Self.extensionKeyPrefix) }
    }

    /// Prefix marking JSON Schema vendor-extension keywords. Every payload key with this
    /// prefix is captured into ``extensions`` verbatim.
    public static let extensionKeyPrefix: String = "x-"
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
        required: [String]? = nil,
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

    /// Accepts any string key, so the decoder can enumerate the raw payload keys and pick
    /// out the `x-*` extensions the typed `CodingKeys` don't model.
    private struct AnyCodingKey: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init(_ stringValue: String) { self.stringValue = stringValue }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
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
                    properties: try container.decodeIfPresent([String: AirshipJSONSchema].self, forKey: .properties),
                    required: try container.decodeIfPresent([String].self, forKey: .required)
                )
            )
        case .array:
            self.type = .array(
                .init(items: try container.decode(AirshipJSONSchema.self, forKey: .items))
            )
        }

        // Capture vendor-extension keywords (`x-*`) verbatim; other unknown keys are ignored.
        let raw = try decoder.container(keyedBy: AnyCodingKey.self)
        var extensions: [String: AirshipJSON] = [:]
        for key in raw.allKeys where key.stringValue.hasPrefix(Self.extensionKeyPrefix) {
            extensions[key.stringValue] = try raw.decode(AirshipJSON.self, forKey: key)
        }
        self.extensions = extensions
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
            try container.encodeIfPresent(info.properties, forKey: .properties)
            try container.encodeIfPresent(info.required, forKey: .required)
        case .array(let info):
            try container.encode(RawType.array, forKey: .type)
            try container.encode(info.items, forKey: .items)
        }

        if !extensions.isEmpty {
            var raw = encoder.container(keyedBy: AnyCodingKey.self)
            for (key, value) in extensions {
                try raw.encode(value, forKey: AnyCodingKey(key))
            }
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

            // Verify all required properties are present.
            if let requiredKeys = info.required {
                for name in requiredKeys {
                    let child = object[name]
                    if child == nil || child == AirshipJSON.null {
                        throw AirshipErrors.error(
                            "Schema validation: missing required property '\(path).\(name)'"
                        )
                    }
                }
            }

            // Validate types for declared properties that are present. No declared
            // properties means the object is unconstrained.
            for (name, property) in info.properties ?? [:] {
                if let child = object[name], child != AirshipJSON.null {
                    try validate(child, against: property, path: "\(path).\(name)")
                }
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
