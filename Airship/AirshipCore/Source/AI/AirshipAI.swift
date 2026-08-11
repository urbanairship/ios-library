/* Copyright Airship and Contributors */

public import Foundation
@_spi(AirshipInternal) import AirshipBasement

/// Namespace for Airship's on-device AI features.
public enum AirshipAI {

    // MARK: - Usage

    /// Identifies an AI use case — one key per feature that can be evaluated, such as
    /// in-app message suppression, scene text input, or embedded selection.
    ///
    /// A usage is what both registration APIs key off: the host supplies context for it
    /// with `setContextProvider(for:_:)`, and `setModelResolver(_:)` routes it to a model.
    ///
    /// `Subject` is a phantom type naming the feature-specific data the provider receives,
    /// so registering a provider for the wrong usage is a compile error.
    public struct Usage<Subject: Sendable>: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
    }

    // MARK: - AnyUsage

    /// A type-erased usage key, used in the `setModelResolver` resolver so a single
    /// closure can route any usage to a model without being generic over `Subject`.
    ///
    /// Compare directly against a typed `Usage<Subject>` with `==`:
    ///
    ///     Airship.ai.setModelResolver { usage in
    ///         if usage == AirshipAI.InAppMessageSuppression.usage { return .custom(myModel) }
    ///         return .defaultModel
    ///     }
    public struct AnyUsage: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
    }

    // MARK: - Context

    /// App-supplied context for a model evaluation.
    ///
    /// Context is an ordered list of prioritized items. The model appends the items to
    /// the evaluation prompt and may drop lower-priority items to fit its input budget.
    ///
    /// Context goes to the model that runs the evaluation and nowhere else — Airship does
    /// not receive, store, or report it. Where the model runs is your choice: the built-in
    /// model keeps it on the device, while a model you configure (Apple's Private Cloud
    /// Compute, or your own backend) sends it wherever that model runs.
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

        /// Renders the items as a bullet list (`- item`), one per item, preserving order.
        ///
        /// - Returns: the bullet list, or nil when there is nothing to render.
        public func renderBullets() -> String? {
            let kept = items.filter { !$0.content.isEmpty }
            guard !kept.isEmpty else { return nil }
            return kept.map { "- \($0.content)" }.joined(separator: "\n")
        }

        /// A copy of this context with `other`'s items appended after this context's.
        ///
        /// Order is meaningful: appended items are "later" and so win priority ties when
        /// trimming (see `dropLowestPriorityItem()`). Used to merge an evaluation's
        /// own context after the provider's.
        public func appending(_ other: Context) -> Context {
            Context(items: items + other.items)
        }

        /// Removes and returns the least-important item — since lower priority values are
        /// more important, this drops the item with the highest value, earliest first within
        /// a value so later (more specific) items win ties. Returns `nil` when the context is
        /// already empty.
        ///
        /// The SDK calls this (through `Request`) to shrink the context when the full prompt
        /// exceeds the model's input window, repeating until the prompt fits.
        mutating func dropLowestPriorityItem() -> Item? {
            guard
                let leastImportant = items.map(\.priority).max(),
                let index = items.firstIndex(where: { $0.priority == leastImportant })
            else {
                return nil
            }
            return items.remove(at: index)
        }
    }

    // MARK: - Availability

    /// Whether the resolved model can be used right now.
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

    /// The outcome of a model evaluation.
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

    /// Selects which model backs an evaluation.
    ///
    /// Returned from the `setModelResolver` closure to route a usage to the appropriate backend.
    public enum ModelSelector: Sendable {
        /// Use the SDK's built-in model — the on-device system model when `AirshipAIModels` is
        /// linked and the device is eligible, otherwise no model.
        case defaultModel
        /// Use a custom model. `AirshipAIModels` ships `AirshipFoundationModel` for anything
        /// conforming to Foundation Models' `LanguageModel`, including Apple's Private Cloud
        /// Compute; implement `AirshipAI.Model` directly to wrap anything else — your own
        /// backend, a third-party inference API, or another on-device runtime.
        case custom(any Model)
    }

    // MARK: - Request

    /// A single request handed to a `Model`.
    ///
    /// Bundles the instructions, output schema, and prioritized context, and knows how to
    /// render itself into prompt text (`prompt()`). Context labeling and layout are owned by
    /// the originating evaluation — a model never formats context itself; it only renders and,
    /// if its input window is tight, trims.
    ///
    /// A model doesn't construct these — the framework builds one per evaluation and hands it
    /// to `Model.respond(_:)`.
    public struct Request: Sendable {

        /// The system instructions (the model's role and rules).
        public let instructions: String

        /// The structured output contract the response must conform to.
        public let schema: AirshipJSONSchema

        /// The prioritized context for this attempt. Shrink it with
        /// `dropLowestPriorityContextItem()`; the setter is private so that's the only path.
        public private(set) var context: Context

        /// Renders `context` into the full prompt. Owned by the evaluation, so the labeling
        /// and ordering match what that feature intends. Kept internal — models call
        /// `prompt()`, they don't invoke this directly.
        let render: @Sendable (Context) -> String

        init(
            instructions: String,
            schema: AirshipJSONSchema,
            context: Context,
            render: @escaping @Sendable (Context) -> String
        ) {
            self.instructions = instructions
            self.schema = schema
            self.context = context
            self.render = render
        }

        /// The full prompt text for the current context.
        public func prompt() -> String {
            render(context)
        }

        /// Drops the least-important context item and returns it, or `nil` when the context
        /// is already empty (nothing to drop). Models call this to shrink a request that
        /// exceeds their input window, re-reading `prompt()` after each drop until it fits;
        /// the returned item is handy for trace logging what was dropped.
        @discardableResult
        public mutating func dropLowestPriorityContextItem() -> Context.Item? {
            context.dropLowestPriorityItem()
        }
    }

    // MARK: - Model protocol

    /// The framework's interface to a model backend.
    ///
    /// Takes a `Request` and returns the model's structured response as parsed JSON. Retry,
    /// timeout, and output validation live in the framework — a model answers one request
    /// and tunes the retry/timeout budget through `maxAttempts`/`responseTimeout`, both of
    /// which have defaults.
    ///
    /// No FoundationModels types appear here — that framework is confined to the
    /// `AirshipAIModels` module.
    public protocol Model: Sendable {

        /// Whether the model can be used right now, and if not, why.
        ///
        /// Queried before each evaluation — the framework skips the run when this is
        /// `.unavailable`. May change over the model's lifetime (e.g. as a model
        /// finishes downloading), so it's read fresh rather than cached.
        ///
        /// Defaults to `.available`. Override it only for a backend that can genuinely
        /// be unusable; otherwise let a failure surface from `respond(_:)`.
        var availability: Availability { get }

        /// A stream of availability changes over the model's lifetime, e.g. as an
        /// on-device model finishes downloading or the OS toggles AI features. Host apps
        /// reach it through `Airship.ai.model(for:)?.availabilityUpdates`.
        ///
        /// The default emits the current value once and finishes — enough for models whose
        /// availability never changes. Models with dynamic availability (e.g. the on-device
        /// system model) override it to emit on every change. Treat it as change
        /// notifications and read `availability` when you need the value right now.
        var availabilityUpdates: AsyncStream<Availability> { get }

        /// How many attempts (including the first) the framework should make before
        /// failing the evaluation. Defaults to 3.
        var maxAttempts: Int { get }

        /// Total wall-clock budget across *all* attempts, not per attempt. The framework
        /// fails the evaluation when it expires. Defaults to 30 seconds.
        ///
        /// A model that answers over the network should raise the budget, lower the
        /// attempt count, or both — three attempts sharing 30 seconds leaves little room
        /// per round trip.
        var responseTimeout: TimeInterval { get }

        /// Answers a single request, returning the model's structured response as JSON.
        ///
        /// At minimum, send `request.prompt()`. A backend with a large enough input window
        /// can stop there.
        ///
        /// If your backend has an input limit and the prompt exceeds it, take a mutable
        /// copy and shrink it one item at a time, re-reading `prompt()` after each drop until
        /// it fits. `dropLowestPriorityContextItem()` returns the item it removed, or `nil`
        /// when the context is already empty:
        ///
        ///     var request = request
        ///     while tooLong(request.prompt()) {
        ///         guard request.dropLowestPriorityContextItem() != nil else { break }
        ///     }
        func respond(_ request: Request) async throws -> AirshipJSON
    }

    // MARK: - ContextProvider

    /// Supplies the context for an evaluation, given the feature-specific `Subject`
    /// (e.g. the message being filtered).
    ///
    /// Called immediately before each evaluation. Return `.empty` when there's nothing
    /// relevant to contribute — the evaluation still runs. Keep the work light; it's on
    /// the path to displaying the feature.
    ///
    /// The SDK holds the provider until it's replaced or cleared, so capture `self`
    /// weakly if the closure reaches back into an object that owns the registration.
    public typealias ContextProvider<Subject: Sendable> = @Sendable (Subject) async -> Context

    // MARK: - Manager protocol

    /// Public entry point for Airship's on-device AI features.
    ///
    /// Accessed via `Airship.ai`. Host apps register context providers and can
    /// configure the backing model globally or per-usage.
    public protocol Manager: Sendable {

        /// Registers a context provider for a usage, or clears it when `provider` is nil.
        ///
        /// The `Subject` phantom type on `Usage` binds the closure's parameter type — a
        /// mismatched provider is a compile error.
        ///
        ///     Airship.ai.setContextProvider(for: AirshipAI.InAppMessageSuppression.usage) { message in
        ///         AirshipAI.Context(items: [.init(content: "Last booked: \(store.lastBooking)")])
        ///     }
        @MainActor
        func setContextProvider<S: Sendable>(
            for usage: Usage<S>,
            _ provider: ContextProvider<S>?
        )

        /// Registers a fallback context provider for usages that have no provider of
        /// their own.
        ///
        /// Receives no feature-specific subject — use it to supply general user context
        /// such as preferences or profile data.
        ///
        /// It is only invoked when the evaluation's usage has no provider set (via
        /// `setContextProvider(for:_:)`). A usage-specific provider wins outright — the two
        /// are never combined. Pass `nil` to remove a previously registered default provider.
        @MainActor
        func setDefaultContextProvider(_ provider: (@Sendable () async -> Context)?)

        /// Registers a per-usage model resolver that routes each usage to a model backend.
        ///
        /// The closure receives a type-erased `AnyUsage` and returns the selector to apply.
        /// Return `.defaultModel` for any usage that should use the SDK's built-in model.
        /// Pass `nil` to clear a previously registered resolver (reverts all usages to the
        /// SDK default).
        ///
        ///     Airship.ai.setModelResolver { usage in
        ///         if usage == AirshipAI.InAppMessageSuppression.usage {
        ///             return .custom(myPrivateComputeModel)
        ///         }
        ///         return .defaultModel
        ///     }
        @MainActor
        func setModelResolver(_ resolver: (@MainActor @Sendable (_ usage: AnyUsage) -> ModelSelector)?)

        /// The SDK's built-in default model, or nil when none is registered
        /// (e.g. `AirshipAIModels` is not linked or the device is ineligible).
        ///
        /// Use this inside a `setModelResolver` closure to make a conditional override — for
        /// example, falling back to a private-compute model only when the on-device model is
        /// unavailable:
        ///
        ///     Airship.ai.setModelResolver { usage in
        ///         if Airship.ai.defaultModel?.availability == .available {
        ///             return .defaultModel
        ///         }
        ///         return .custom(myFallbackModel)
        ///     }
        @MainActor
        var defaultModel: (any Model)? { get }

        /// Returns the model currently resolved for `usage`, or nil when no model is
        /// configured or available (none registered, below OS minimum, etc.).
        ///
        /// The model's `availability` and `availabilityUpdates` reflect whether it can run
        /// right now:
        ///
        ///     Airship.ai.model(for: AirshipAI.InAppMessageSuppression.usage)?.availability
        ///     Airship.ai.model(for: AirshipAI.InAppMessageSuppression.usage)?.availabilityUpdates
        ///
        /// The per-usage resolver (set via `setModelResolver`) wins over the SDK default.
        @MainActor
        func model<S: Sendable>(for usage: Usage<S>) -> (any Model)?
    }

    // MARK: - Evaluation protocol (SPI)

    /// A typed request submitted to the resolved model.
    ///
    /// Feature modules define concrete evaluations; `Output` is decoded from the
    /// model's JSON response. `Subject` is the feature-specific context type whose
    /// instance is passed to the registered `ContextProvider` at evaluation time.
    @_spi(AirshipInternal)
    public protocol Evaluation<Output>: Sendable {
        /// The decoded type the model returns for this evaluation.
        associatedtype Output: Decodable & Sendable

        /// The feature-specific subject type passed to the registered `ContextProvider`.
        associatedtype Subject: Sendable

        /// Identifies which AI usage this evaluation belongs to, and binds the subject
        /// type the registered provider receives.
        var usage: Usage<Subject> { get }

        /// The context subject for this evaluation — passed to the registered
        /// `ContextProvider<Subject>` to produce the `Context` for the prompt.
        var subject: Subject { get }

        /// The structured output contract for this evaluation. Static features declare
        /// it in code; payload-driven features (e.g. scenes) decode it from the payload.
        var schema: AirshipJSONSchema { get }

        /// Returns the system instructions sent to the model — the stable, evaluation-wide
        /// directives that define the model's role, rules, and output expectations.
        /// Injected as the system prompt; the model sees this before any user turn.
        func instructions() -> String

        /// Builds the prompt sent to the model. `context` is the context as trimmed so
        /// far — a model whose input window is tight drops low-priority items and calls
        /// this again after each drop until the prompt fits.
        ///
        /// Implementations are expected to render `context` into the prompt. Nothing
        /// enforces it — an implementation that ignores the parameter still runs, but the
        /// context is fetched and trimmed for a prompt it never reaches, so that work is
        /// wasted. If an evaluation genuinely wants no context, don't register a provider
        /// (and pass none to `evaluate`) rather than dropping it here.
        func prompt(context: Context) -> String

        /// When true, the evaluation is skipped (`.skipped`) if the resolved context is
        /// empty — there is nothing to personalize on, so the model would only guess from
        /// the prompt. Defaults to false: most evaluations run regardless (e.g. suppression
        /// fails open). Opt in only when an empty context makes the model's answer arbitrary.
        var requiresContext: Bool { get }
    }

    // MARK: - InternalManager protocol (SPI)

    /// Internal SDK surface for the AI manager. Extends `Manager` with evaluation
    /// and model registration — injected into feature modules via
    /// `AirshipModuleLoaderArgs` so they can be tested with a mock.
    @_spi(AirshipInternal)
    public protocol InternalManager: Manager {

        /// Runs an evaluation through the active model. Feature modules call this;
        /// fails open — returns `.skipped` when the model is unavailable.
        ///
        /// `additionalContext` is layout- or feature-authored context appended after the
        /// provider's context (so it wins priority ties when the model trims to fit its window).
        /// Use `evaluate(_:)` (no additional context) for the common case.
        func evaluate<E: Evaluation>(_ evaluation: E, additionalContext: Context) async -> Result<E.Output>

        /// Called by `AirshipAIModelsSDKModule` to wire in the on-device model as the
        /// default. Replaces the current model immediately.
        @MainActor
        func registerModelFactory(
            _ factory: @MainActor @Sendable @escaping () -> any Model
        )

        /// Fetches the registered provider's context for the given usage and subject —
        /// the usage-specific provider if there is one, otherwise the default provider.
        /// Returns `.empty` when neither is registered. Does not include the
        /// `additionalContext` an evaluation may append.
        func fetchContext<S: Sendable>(for usage: Usage<S>, subject: S) async -> Context
    }
}

// MARK: - Default implementations

@_spi(AirshipInternal)
extension AirshipAI.Evaluation {
    /// Most evaluations run regardless of context; opt in by overriding.
    public var requiresContext: Bool { false }
}

extension AirshipAI.Model {
    /// Assumes the model can be used. Correct for a backend that has no readiness
    /// state of its own — a failure surfaces from `respond(_:)` instead. Models
    /// that can genuinely be unusable override this.
    public var availability: AirshipAI.Availability { .available }

    /// Emits the current availability once and finishes — correct for models whose
    /// availability never changes. Dynamic models override this.
    public var availabilityUpdates: AsyncStream<AirshipAI.Availability> {
        let availability = self.availability
        return AsyncStream { continuation in
            continuation.yield(availability)
            continuation.finish()
        }
    }

    /// A reasonable default. Override for a backend where a retry is expensive.
    public var maxAttempts: Int { 3 }

    /// A reasonable default. Override for a backend that answers over the network.
    public var responseTimeout: TimeInterval { 30 }
}

@_spi(AirshipInternal)
extension AirshipAI.InternalManager {
    public func evaluate<E: AirshipAI.Evaluation>(_ evaluation: E) async -> AirshipAI.Result<E.Output> {
        await evaluate(evaluation, additionalContext: .empty)
    }
}

// MARK: - AnyUsage cross-type equality

extension AirshipAI.AnyUsage {
    public static func == <S: Sendable>(lhs: Self, rhs: AirshipAI.Usage<S>) -> Bool {
        lhs.rawValue == rhs.rawValue
    }
    public static func == <S: Sendable>(lhs: AirshipAI.Usage<S>, rhs: Self) -> Bool {
        lhs.rawValue == rhs.rawValue
    }
}
