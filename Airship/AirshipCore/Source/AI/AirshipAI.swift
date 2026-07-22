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

        /// A single piece of context. `content` should be self-describing text
        /// (e.g. `"Favorite category: hiking"`) — it is inserted into the prompt as-is.
        public struct Item: Sendable, Equatable {
            public var content: String

            /// Relative importance, where **lower is more important**. When the prompt
            /// exceeds the model's input window, items with the highest priority value
            /// are dropped first. Any value is valid — negatives rank above the `0`
            /// default. Providers and layout-authored context share this one numeric scale.
            public var priority: Double

            public init(content: String, priority: Double = 0.0) {
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

        /// A copy of this context with `other`'s items appended after this context's.
        ///
        /// Order is meaningful: appended items are "later" and so win priority ties when
        /// trimming (see `droppingLowestPriorityItem()`). Used to merge an evaluation's
        /// own context after the provider's.
        public func appending(_ other: Context) -> Context {
            Context(items: items + other.items)
        }

        /// A copy of this context with the least-important item removed — since lower
        /// priority values are more important, this drops the item with the highest
        /// value, earliest first within a value so later (more specific) items win ties.
        ///
        /// Models call this to shrink the context when the full prompt exceeds their
        /// input window, repeating until the prompt fits.
        ///
        /// - Returns: the reduced context, or nil when there is nothing left to drop.
        public func droppingLowestPriorityItem() -> Context? {
            guard
                let leastImportant = items.map(\.priority).max(),
                let index = items.firstIndex(where: { $0.priority == leastImportant })
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
    /// Ungated so the host app can query it without an `#available` check. When no
    /// model is resolved (e.g. below the OS minimum, or none registered) the default
    /// is `.unavailable(reason: .missingModel)`.
    public enum Availability: Sendable, Equatable {
        case available
        case unavailable(reason: Reason)

        /// Why a model can't be used right now.
        ///
        /// Kept model-agnostic: these describe outcomes a host app can act on, not
        /// the internals of any particular (on-device or otherwise) backend.
        public enum Reason: Sendable, Equatable {
            /// The device or OS can't run the model (ineligible hardware or an
            /// unsupported OS version).
            case deviceNotEligible
            /// No usable model is available — not downloaded, still preparing, or
            /// simply not registered.
            case missingModel
            /// AI features are turned off, by the user or by configuration.
            case notEnabled
            /// Any other reason, carrying a human-readable description.
            case other(String)
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

        /// Whether the model can be used right now, and if not, why.
        ///
        /// Queried before each evaluation — the framework skips the run when this is
        /// `.unavailable`. May change over the model's lifetime (e.g. as a model
        /// finishes downloading), so it's read fresh rather than cached.
        var availability: Availability { get }

        /// A stream of availability changes over the model's lifetime, e.g. as an
        /// on-device model finishes downloading or the OS toggles AI features. The
        /// framework observes this to drive `Manager.availabilityUpdates`.
        ///
        /// The default emits the current value once — enough for models whose
        /// availability never changes. Models with dynamic availability (e.g. the
        /// on-device system model) override it to emit on every change.
        var availabilityUpdates: AsyncStream<Availability> { get }

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

        /// Supplies the on-device context for an evaluation of `subject`.
        ///
        /// Called on the main actor immediately before each evaluation. Return
        /// `.empty` when there's nothing relevant to contribute — the evaluation
        /// still runs. Keep the work light; it's on the path to displaying the
        /// feature.
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

        /// Registers a fallback context provider for usages that have no provider of
        /// their own.
        ///
        /// Receives no feature-specific subject (`Subject == Void`) — use it to supply
        /// general user context such as preferences or profile data.
        ///
        /// It is only invoked when the evaluation's usage has no typed provider set (via
        /// `setProvider(_:for:)`). A usage-specific provider wins outright — the two are
        /// never combined. Pass `nil` to remove a previously registered default provider.
        @MainActor
        func setDefaultProvider(_ provider: (any ContextProvider<Void>)?)

        /// Overrides the model used for all evaluations. Use `.defaultModel` to restore
        /// the SDK default.
        @MainActor
        func setModel(_ selector: ModelSelector)

        /// Whether the active model can be used right now.
        @MainActor
        var availability: Availability { get }

        /// A stream of availability changes, starting with the current value and emitting
        /// whenever it changes — the active model finishing a download, the OS toggling AI
        /// features, or a `setModel`/model-factory swap. Consumers can gate UI on live
        /// availability instead of a stale render-time snapshot.
        @MainActor
        var availabilityUpdates: AsyncStream<Availability> { get }
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

        /// Context the evaluation contributes itself, appended after the provider's
        /// context (so it wins priority ties when trimming). Payload-driven features
        /// carry authored context here; most evaluations leave it `.empty` (the default).
        var additionalContext: Context { get }

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

// MARK: - Default implementations

extension AirshipAI.Model {
    /// Emits the current availability once and finishes — correct for models whose
    /// availability never changes. Dynamic models override this.
    public var availabilityUpdates: AsyncStream<AirshipAI.Availability> {
        let availability = self.availability
        return AsyncStream { continuation in
            continuation.yield(availability)
            continuation.finish()
        }
    }
}

@_spi(AirshipInternal)
extension AirshipAI.Evaluation {
    /// Most evaluations contribute no context of their own.
    public var additionalContext: AirshipAI.Context { .empty }
}
