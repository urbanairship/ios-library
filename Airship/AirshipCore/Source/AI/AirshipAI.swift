/* Copyright Airship and Contributors */

import Foundation

/// Namespace for Airship's on-device AI features.
public enum AirshipAI {

    // MARK: - Usage

    /// Identifies what an on-device model evaluation is for.
    /// Add cases here as AI features are wired up across modules.
    public enum Usage: Sendable, Hashable, Codable {
        case inAppMessageFilter
    }

    // MARK: - Context

    /// App-supplied context for an on-device model evaluation.
    ///
    /// Everything here stays on device — it is fed to the on-device model and never
    /// leaves the SDK.
    public struct Context: Sendable, Equatable {

        /// Free-form natural language the model reads directly.
        public var summary: String?

        /// Structured key/value hints (e.g. `["favorite_category": "hiking"]`).
        public var attributes: [String: String]

        public init(
            summary: String? = nil,
            attributes: [String: String] = [:]
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

        public enum FieldType: String, Sendable, Equatable {
            case string
            case boolean
            case integer
            case number
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
    /// response as a JSON string. No FoundationModels types appear here — only
    /// `SystemAIModel` (in the `AirshipAI` module) touches FoundationModels.
    public protocol Model: Sendable {

        var availability: Availability { get }

        func respond(
            instructions: String,
            prompt: String,
            schema: Schema
        ) async throws -> String
    }

    // MARK: - ContextProvider protocol

    /// Implemented by the host app to supply on-device context for AI evaluations.
    public protocol ContextProvider: AnyObject, Sendable {
        @MainActor
        func context(for usage: Usage) async -> Context
    }

    // MARK: - Manager protocol

    /// Public entry point for Airship's on-device AI features.
    ///
    /// Accessed via `Airship.ai`. Host apps register context providers and can
    /// swap the backing model here.
    public protocol Manager: Sendable {

        /// Registers a context provider for a usage, or clears it when `provider` is nil.
        @MainActor
        func setProvider(
            _ provider: (any ContextProvider)?,
            for usage: Usage
        )

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
    /// model's JSON response. No FoundationModels types appear here.
    @_spi(AirshipInternal)
    public protocol Evaluation<Output>: Sendable {
        associatedtype Output: Decodable & Sendable

        var usage: Usage { get }

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
        func setSchema(_ schema: Schema, for usage: Usage)

        /// Returns the schema registered for a usage.
        @MainActor
        func schema(for usage: Usage) -> Schema?

        /// Called by `AirshipAIModelsSDKModule` to wire in `SystemAIModel` as the
        /// default. Replaces the current model immediately.
        @MainActor
        func registerModelFactory(
            _ factory: @MainActor @Sendable @escaping () -> any Model
        )
    }
}

// MARK: - Schema instruction helper

extension AirshipAI.Schema {
    /// A natural-language description of the expected JSON shape, ready to append
    /// to model instructions. Model implementors can include this in the system
    /// prompt to constrain output without guided generation.
    public var instruction: String {
        let lines = fields.map { field -> String in
            let requirement = field.isRequired ? "required" : "optional"
            let description = field.description.map { " — \($0)" } ?? ""
            return "  \"\(field.name)\": \(field.type.rawValue) (\(requirement))\(description)"
        }
        return """
        Respond with ONLY a single JSON object (no markdown, no prose) with these fields:
        {
        \(lines.joined(separator: ",\n"))
        }
        """
    }
}
