/* Copyright Airship and Contributors */

public import Foundation
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
    /// Context is an ordered list of prioritized items. The model appends the items to
    /// the evaluation prompt and may drop lower-priority items to fit its input budget.
    /// Everything here stays on device — it is fed to the on-device model and never
    /// leaves the SDK.
    public struct Context: Sendable, Equatable {

        /// Relative importance of a context item. Models drop lower-priority items
        /// first when trimming context to fit their input budget.
        public enum Priority: Int, Sendable, Equatable, Comparable, CaseIterable {
            case low = 0
            case medium = 1
            case high = 2

            public static func < (lhs: Priority, rhs: Priority) -> Bool {
                lhs.rawValue < rhs.rawValue
            }
        }

        /// A single piece of context. `content` should be self-describing text
        /// (e.g. `"Favorite category: hiking"`) — it is inserted into the prompt as-is.
        public struct Item: Sendable, Equatable {
            public var content: String
            public var priority: Priority

            public init(content: String, priority: Priority = .medium) {
                self.content = content
                self.priority = priority
            }
        }

        /// Context pieces in presentation order.
        public var items: [Item]

        public init(items: [Item] = []) {
            self.items = items
        }

        /// An empty context, used when the host supplies nothing.
        public static let empty = Context()

        /// Renders the items into prompt text, one per line, preserving order.
        ///
        /// - Returns: the rendered context, or nil when there is nothing to render.
        public func render() -> String? {
            let kept = items.filter { !$0.content.isEmpty }
            guard !kept.isEmpty else { return nil }
            return kept.map(\.content).joined(separator: "\n")
        }

        /// A copy of this context with the lowest-priority item removed — earliest
        /// first within a priority, so later (more specific) providers win ties.
        ///
        /// Models call this to shrink the context when the full prompt exceeds their
        /// input window, repeating until the prompt fits.
        ///
        /// - Returns: the reduced context, or nil when there is nothing left to drop.
        public func droppingLowestPriorityItem() -> Context? {
            guard
                let lowest = items.map(\.priority).min(),
                let index = items.firstIndex(where: { $0.priority == lowest })
            else {
                return nil
            }
            var reduced = items
            reduced.remove(at: index)
            return Context(items: reduced)
        }
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

    // MARK: - ModelSelector

    public enum ModelSelector: Sendable {
        case defaultModel
        case custom(any Model)
    }

    // MARK: - Model protocol

    /// Thin, backend-agnostic wrapper over a model.
    ///
    /// Takes instructions + a prompt + prioritized context + a schema and returns the
    /// model's structured response as parsed JSON. Retry, timeout, and output
    /// validation live in the framework — a model answers a single request and
    /// declares its retry/timeout policy through `maxAttempts`/`responseTimeout`.
    /// No FoundationModels types appear here — only `SystemAIModel` (in the
    /// `AirshipAIModels` module) touches FoundationModels.
    public protocol Model: Sendable {

        var availability: Availability { get }

        /// How many attempts (including the first) the framework should make before
        /// failing the evaluation. Airship's on-device model uses 3.
        var maxAttempts: Int { get }

        /// Total wall-clock budget across all attempts. The framework fails the
        /// evaluation when it expires. Airship's on-device model uses 30 seconds.
        var responseTimeout: TimeInterval { get }

        /// Answers a single request. The model appends `context` to the prompt; when
        /// the prompt exceeds its input window it should shrink the context via
        /// `Context.droppingLowestPriorityItem()` and try again.
        func respond(
            instructions: String,
            prompt: String,
            context: Context,
            schema: AirshipJSONSchema
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

        /// The structured output contract for this evaluation. Static features declare
        /// it in code; payload-driven features (e.g. scenes) decode it from the payload.
        var schema: AirshipJSONSchema { get }

        func instructions() -> String

        /// The subject portion of the prompt. Provider context is fetched by the
        /// framework and appended by the model, which may trim low-priority items.
        func prompt() -> String
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

        /// Called by `AirshipAIModelsSDKModule` to wire in `SystemAIModel` as the
        /// default. Replaces the current model immediately.
        @MainActor
        func registerModelFactory(
            _ factory: @MainActor @Sendable @escaping () -> any Model
        )

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
