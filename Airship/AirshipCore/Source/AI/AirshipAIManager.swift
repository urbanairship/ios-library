/* Copyright Airship and Contributors */

import Foundation
@_spi(AirshipInternal) import AirshipBasement

extension AirshipAI {
    final class DefaultManager: InternalManager, Sendable {

        @MainActor
        private var overrideResolver: (@MainActor @Sendable (AnyUsage) -> ModelSelector)?

        @MainActor
        private var defaultModelFactory: (@MainActor @Sendable () -> any AirshipAI.ModelProtocol)?

        @MainActor
        private let providerRegistry = ProviderRegistry()

        private let evaluator = AirshipAI.Evaluator()

        private let privacyManager: any AirshipPrivacyManager

        /// `Airship.ai` is gated by `AirshipFeature.onDeviceAI` — disabled, evaluations and
        /// context fetches behave as though no model were ever registered.
        private var enabled: Bool {
            privacyManager.isEnabled(.onDeviceAI)
        }

        @_spi(AirshipInternal)
        public init(privacyManager: any AirshipPrivacyManager) {
            self.privacyManager = privacyManager
        }

        @MainActor
        private func resolve(_ selector: ModelSelector) -> (any AirshipAI.ModelProtocol)? {
            switch selector {
            case .defaultModel: return defaultModelFactory?()
            case .custom(let m): return m
            }
        }

        @MainActor
        public var defaultModel: (any AirshipAI.ModelProtocol)? {
            guard enabled else { return nil }
            return defaultModelFactory?()
        }

        @MainActor
        public func model<S: Sendable>(for usage: Usage<S>) -> (any AirshipAI.ModelProtocol)? {
            guard enabled else { return nil }
            let selector = overrideResolver?(AnyUsage(rawValue: usage.rawValue)) ?? .defaultModel
            return resolve(selector)
        }

        /// Same resolution as `model(for:)`, but wraps the result so its `availability`/
        /// `availabilityUpdates` also reflect `AirshipFeature.onDeviceAI` — for a caller that
        /// resolves once and holds onto the result for a long lifetime (e.g. a scene's AI
        /// executor) and needs it to stay in sync with privacy manager changes, rather than
        /// re-resolving on every check. `model(for:)` itself is left untouched so callers that
        /// need the exact registered instance (identity/type checks) keep getting it.
        @MainActor
        public func gatedModel<S: Sendable>(for usage: Usage<S>) -> (any AirshipAI.ModelProtocol)? {
            let selector = overrideResolver?(AnyUsage(rawValue: usage.rawValue)) ?? .defaultModel
            guard let model = resolve(selector) else { return nil }
            return PrivacyGatedModel(wrapped: model, privacyManager: privacyManager)
        }

        @MainActor
        public func setContextProvider<S: Sendable>(
            for usage: Usage<S>,
            _ provider: ContextProvider<S>?
        ) {
            providerRegistry.setContextProvider(for: usage, provider)
        }

        @MainActor
        public func setDefaultContextProvider(_ provider: (@Sendable () async -> Context)?) {
            providerRegistry.setDefaultContextProvider(provider)
        }

        @MainActor
        public func setModelResolver(_ resolver: (@MainActor @Sendable (AnyUsage) -> ModelSelector)?) {
            overrideResolver = resolver
        }

        @MainActor
        public func registerModelFactory(
            _ factory: @MainActor @Sendable @escaping () -> any AirshipAI.ModelProtocol
        ) {
            defaultModelFactory = factory
        }

        public func fetchContext<S: Sendable>(
            for usage: AirshipAI.Usage<S>,
            subject: S
        ) async -> AirshipAI.Context {
            guard enabled else { return .empty }
            return await providerContext(forUsage: usage.rawValue, subject: subject)
        }

        public func evaluate<E: AirshipAI.Evaluation>(
            _ evaluation: E,
            additionalContext: AirshipAI.Context
        ) async -> AirshipAI.Result<E.Output> {
            guard enabled else {
                return .skipped(reason: "AI disabled by privacy manager")
            }
            guard let resolved = await resolve(evaluation) else {
                return .skipped(reason: "No model configured")
            }
            // Provider context first, then the caller's additional context appended after
            // (later items win priority ties when the model trims to fit its window).
            let merged = resolved.context.appending(additionalContext)

            // Some evaluations are only meaningful with context (e.g. embedded selection):
            // with none, the model would guess from the prompt alone, so skip and let the
            // caller fall back. Most evaluations opt out and run regardless (fail open).
            if evaluation.requiresContext, merged.items.isEmpty {
                return .skipped(reason: "No context to personalize on")
            }

            return await evaluator.evaluate(evaluation, model: resolved.model, context: merged)
        }

        /// Resolves the model and fetches the provider's context. Model resolution and the
        /// provider lookup both read main-actor state, so they share one hop; the provider's
        /// own work runs with whatever isolation it declares. Returns nil (skipping the
        /// context fetch) when no model is configured.
        @MainActor
        private func resolve<E: AirshipAI.Evaluation>(
            _ evaluation: E
        ) async -> (model: any AirshipAI.ModelProtocol, context: AirshipAI.Context)? {
            guard let model = self.model(for: evaluation.usage) else { return nil }
            let context = await providerContext(
                forUsage: evaluation.usage.rawValue,
                subject: evaluation.subject
            )
            return (model, context)
        }

        /// Fetches the registered provider's context for a usage, or `.empty` when none is
        /// registered. The lookup runs on the main actor; awaiting the fetcher leaves it.
        @MainActor
        private func providerContext(
            forUsage rawValue: String,
            subject: any Sendable
        ) async -> AirshipAI.Context {
            await providerRegistry.contextFetcher(for: rawValue)?(subject) ?? .empty
        }
    }

    /// A resolved model wrapped so its availability reflects `AirshipFeature.onDeviceAI` in
    /// addition to the underlying model's own state. See `DefaultManager.gatedModel(for:)`.
    private struct PrivacyGatedModel: ModelProtocol {
        let wrapped: any ModelProtocol
        let privacyManager: any AirshipPrivacyManager

        private func gate(_ availability: Availability) -> Availability {
            guard privacyManager.isEnabled(.onDeviceAI) else {
                return .unavailable(reason: .notEnabled)
            }
            return availability
        }

        var availability: Availability {
            gate(wrapped.availability)
        }

        var availabilityUpdates: AsyncStream<Availability> {
            let wrappedUpdates = wrapped.availabilityUpdates
            let privacyUpdates = privacyManager.updates
            let gate: @Sendable (Availability) -> Availability = self.gate

            // Both source streams replay their current value on subscription, so without
            // de-duplication the merge below would emit that shared starting value twice.
            let lastEmitted = AirshipAtomicValue<Availability?>(nil)
            func emit(_ continuation: AsyncStream<Availability>.Continuation, _ availability: Availability) {
                let value = gate(availability)
                if lastEmitted.setValue(value) {
                    continuation.yield(value)
                }
            }

            return AsyncStream { continuation in
                let privacyTask = Task {
                    for await _ in privacyUpdates {
                        emit(continuation, wrapped.availability)
                    }
                }

                let modelTask = Task {
                    for await availability in wrappedUpdates {
                        emit(continuation, availability)
                    }
                }

                continuation.onTermination = { _ in
                    privacyTask.cancel()
                    modelTask.cancel()
                }
            }
        }

        var maxAttempts: Int { wrapped.maxAttempts }
        var responseTimeout: TimeInterval { wrapped.responseTimeout }

        func respond(_ request: Request) async throws -> AirshipJSON {
            try await wrapped.respond(request)
        }
    }
}
