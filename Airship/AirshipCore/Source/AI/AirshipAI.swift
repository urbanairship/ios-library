/* Copyright Airship and Contributors */

import Foundation
@_spi(AirshipInternal) import AirshipBasement

/// Namespace for Airship's on-device AI features.
public enum AirshipAI {

    // MARK: - Usage

    /// Identifies what an on-device model evaluation is for.
    ///
    /// `Subject` is a phantom type that ties a usage to its typed context provider,
    /// giving compile-time guarantees at `setProvider` call sites.
    public struct Usage<Subject: Sendable>: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
    }

    // MARK: - Context

    /// App-supplied context for an on-device model evaluation.
    ///
    /// Everything here stays on device — it is fed to the on-device model and never
    /// leaves the SDK.
    public struct Context: Sendable, Equatable {

        /// Free-form natural language the model reads directly.
        public var summary: String?

        /// Structured key/value hints (e.g. `["favorite_category": .string("hiking")]`).
        public var attributes: [String: AirshipJSON]

        public init(
            summary: String? = nil,
            attributes: [String: AirshipJSON] = [:]
        ) {
            self.summary = summary
            self.attributes = attributes
        }

        /// An empty context, used when the host supplies nothing.
        public static let empty = Context()
    }

    // MARK: - Availability

    /// Whether the on-device model can be used right now.
    ///
    /// Ungated so the host app can query it without an `#available` check. Below
    /// iOS 26 the default model is always `.unavailable(reason: .osVersion)`.
    public enum Availability: Sendable, Equatable {
        case available
        case unavailable(reason: Reason)

        public enum Reason: Sendable, Equatable {
            /// OS is below the minimum required for on-device models (iOS 26).
            case osVersion
            /// Hardware is not eligible for Apple Intelligence.
            case deviceNotEligible
            /// Apple Intelligence is not enabled by the user.
            case appleIntelligenceNotEnabled
            /// The model is still downloading / warming up.
            case modelNotReady
            case unknown
        }
    }

    // MARK: - Result

    /// The outcome of an on-device model evaluation.
    ///
    /// Treat anything that isn't `.completed` as "no opinion" and proceed with
    /// default behavior.
    public enum Result<Output: Sendable>: Sendable {

        /// The model produced a structured result.
        case completed(Output)

        /// The evaluation was not run (model unavailable, no context provider, etc.).
        case skipped(reason: String)

        /// The evaluation started but threw.
        case failed(any Error)

        /// The structured output if the evaluation completed, otherwise nil.
        public var output: Output? {
            if case .completed(let output) = self { return output }
            return nil
        }
    }

    // MARK: - Schema

    /// Describes the structured JSON output an evaluation expects from the model.
    ///
    /// Backend-agnostic — exposes no Apple FoundationModels types.
    public struct Schema: Sendable, Equatable {

        public indirect enum FieldType: Sendable, Equatable {
            case string
            case boolean
            case integer
            case number
            /// A nested object with its own fields.
            case object(fields: [Field])
            /// An array whose elements all conform to `element`.
            case array(element: FieldType)
        }

        public struct Field: Sendable, Equatable {
            public let name: String
            public let type: FieldType
            public let description: String?
            public let isRequired: Bool

            public init(
                name: String,
                type: FieldType,
                description: String? = nil,
                isRequired: Bool = true
            ) {
                self.name = name
                self.type = type
                self.description = description
                self.isRequired = isRequired
            }
        }

        public let fields: [Field]

        public init(fields: [Field]) {
            self.fields = fields
        }
    }

    // MARK: - ModelSelector

    public enum ModelSelector: Sendable {
        case defaultModel
        case custom(any Model)
    }

    // MARK: - Model protocol

    /// Thin, backend-agnostic wrapper over a model.
    ///
    /// Takes instructions + a prompt + a schema and returns the model's structured
    /// response as parsed JSON. No FoundationModels types appear here — only
    /// `SystemAIModel` (in the `AirshipAIModels` module) touches FoundationModels.
    public protocol Model: Sendable {

        var availability: Availability { get }

        func respond(
            instructions: String,
            prompt: String,
            schema: Schema
        ) async throws -> AirshipJSON
    }

    // MARK: - ContextProvider protocol

    /// Implemented by the host app to supply on-device context for AI evaluations.
    ///
    /// `Subject` is the type of the feature-specific data the provider receives
    /// (e.g. the message being filtered). The `Usage<Subject>` phantom type ensures
    /// the correct provider is registered at the correct call site.
    public protocol ContextProvider<Subject>: AnyObject, Sendable {
        associatedtype Subject: Sendable
        @MainActor
        func context(for subject: Subject) async -> Context
    }

    // MARK: - Manager protocol

    /// Public entry point for Airship's on-device AI features.
    ///
    /// Accessed via `Airship.ai`. Host apps register context providers and can
    /// swap the backing model here.
    public protocol Manager: Sendable {

        /// Registers a typed context provider for a usage, or clears it when `provider` is nil.
        ///
        /// The `Subject` phantom type on `Usage` ensures the provider's `Subject` matches
        /// the usage — a mismatched provider is a compile error.
        @MainActor
        func setProvider<S: Sendable>(
            _ provider: (any ContextProvider<S>)?,
            for usage: Usage<S>
        )

        /// Registers a default context provider invoked for every evaluation.
        ///
        /// The default provider receives no feature-specific subject (`Subject == Void`) — use
        /// it to supply general user context such as preferences or profile data.
        ///
        /// When a typed provider is also registered for a usage, both are called and their
        /// contexts are merged: the typed provider's values take precedence over the default.
        /// Pass `nil` to remove a previously registered default provider.
        @MainActor
        func setDefaultProvider(_ provider: (any ContextProvider<Void>)?)

        /// Overrides the model used for all evaluations. Use `.defaultModel` to restore
        /// the SDK default.
        @MainActor
        func setModel(_ selector: ModelSelector)

        /// Whether the active model can be used right now.
        @MainActor
        var availability: Availability { get }
    }

    // MARK: - Evaluation protocol (SPI)

    /// A typed request submitted to the on-device model.
    ///
    /// Feature modules define concrete evaluations; `Output` is decoded from the
    /// model's JSON response. `Subject` is the feature-specific context type whose
    /// instance is passed to the registered `ContextProvider` at evaluation time.
    @_spi(AirshipInternal)
    public protocol Evaluation<Output>: Sendable {
        associatedtype Output: Decodable & Sendable
        associatedtype Subject: Sendable

        var usage: Usage<Subject> { get }

        /// The context subject for this evaluation — passed to the registered
        /// `ContextProvider<Subject>` to produce the `Context` for the prompt.
        var subject: Subject { get }

        func instructions() -> String
        func prompt(context: Context) -> String
    }

    // MARK: - InternalManager protocol (SPI)

    /// Internal SDK surface for the AI manager. Extends `Manager` with evaluation
    /// and model registration — injected into feature modules via
    /// `AirshipModuleLoaderArgs` so they can be tested with a mock.
    @_spi(AirshipInternal)
    public protocol InternalManager: Manager {

        /// Runs an evaluation through the active model. Feature modules call this;
        /// fails open — returns `.skipped` when the model is unavailable.
        func evaluate<E: Evaluation>(_ evaluation: E) async -> Result<E.Output>

        /// Registers the schema for a usage. Feature modules call this at startup
        /// so the schema is available during evaluation.
        @MainActor
        func setSchema<S: Sendable>(_ schema: Schema, for usage: Usage<S>)

        /// Returns the schema registered for a usage.
        @MainActor
        func schema<S: Sendable>(for usage: Usage<S>) -> Schema?

        /// Called by `AirshipAIModelsSDKModule` to wire in `SystemAIModel` as the
        /// default. Replaces the current model immediately.
        @MainActor
        func registerModelFactory(
            _ factory: @MainActor @Sendable @escaping () -> any Model
        )

        /// Raw keys of all usages that have a registered schema.
        @MainActor
        var registeredUsageKeys: [String] { get }

        /// Fetches the merged context that would be passed to the model for the given usage and subject.
        /// Returns `.empty` if no provider is registered.
        func fetchContext<S: Sendable>(for usage: Usage<S>, subject: S) async -> Context
    }
}

// MARK: - Usage Codable

extension AirshipAI.Usage: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(String.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

// MARK: - Schema instruction helper

extension AirshipAI.Schema {
    /// A natural-language description of the expected JSON shape, ready to append
    /// to model instructions. Model implementors can include this in the system
    /// prompt to constrain output without guided generation.
    public var instruction: String {
        let lines = fields.map { "  \(Self.describe(field: $0))" }
        return """
        *Return the data in JSON format. Do not use markdown backticks or fences.*
        The response must start with { and end with }. Fields:
        {
        \(lines.joined(separator: ",\n"))
        }
        """
    }

    /// Renders a single field as `"name": <type> (required|optional) — description`.
    private static func describe(field: Field) -> String {
        let requirement = field.isRequired ? "required" : "optional"
        let description = field.description.map { " — \($0)" } ?? ""
        return "\"\(field.name)\": \(describe(type: field.type)) (\(requirement))\(description)"
    }

    /// Renders a field type, recursing into nested objects and arrays.
    private static func describe(type: FieldType) -> String {
        switch type {
        case .string: return "string"
        case .boolean: return "boolean"
        case .integer: return "integer"
        case .number: return "number"
        case .object(let fields):
            let inner = fields.map { describe(field: $0) }.joined(separator: ", ")
            return "{ \(inner) }"
        case .array(let element):
            return "array of \(describe(type: element))"
        }
    }
}

// MARK: - Schema validation

extension AirshipAI.Schema {
    /// Validates that `json` conforms to this schema.
    ///
    /// Extra keys not described by the schema are ignored. Optional fields may be
    /// absent or null.
    ///
    /// - Throws: an error describing the first violation; returns normally if valid.
    public func validate(_ json: AirshipJSON) throws {
        try Self.validate(json, against: .object(fields: fields), path: "$")
    }

    private static func validate(
        _ value: AirshipJSON,
        against type: FieldType,
        path: String
    ) throws {
        switch type {
        case .string:
            guard value.isString else { throw typeError(path, "string", value) }
        case .boolean:
            guard value.isBool else { throw typeError(path, "boolean", value) }
        case .integer:
            guard let number = value.number, number.rounded() == number else {
                throw typeError(path, "integer", value)
            }
        case .number:
            guard value.isNumber else { throw typeError(path, "number", value) }
        case .object(let fields):
            guard let object = value.object else { throw typeError(path, "object", value) }
            for field in fields {
                let child = object[field.name]
                if child == nil || child == AirshipJSON.null {
                    if field.isRequired {
                        throw AirshipErrors.error(
                            "Schema validation: missing required field '\(path).\(field.name)'"
                        )
                    }
                    continue
                }
                try validate(child!, against: field.type, path: "\(path).\(field.name)")
            }
        case .array(let element):
            guard let array = value.array else { throw typeError(path, "array", value) }
            for (index, item) in array.enumerated() {
                try validate(item, against: element, path: "\(path)[\(index)]")
            }
        }
    }

    private static func typeError(_ path: String, _ expected: String, _ value: AirshipJSON) -> any Error {
        AirshipErrors.error("Schema validation: expected \(expected) at '\(path)'")
    }
}
