/* Copyright Airship and Contributors */

import Foundation

extension AirshipAI {
    final class DefaultManager: InternalManager, Sendable {

        @MainActor
        private var overrideResolver: (@MainActor @Sendable (AnyUsage) -> ModelSelector)?

        @MainActor
        private var defaultModelFactory: (@MainActor @Sendable () -> any AirshipAI.Model)?

        @MainActor
        private let providerRegistry = ProviderRegistry()

        private let evaluator = AirshipAI.Evaluator()

        @_spi(AirshipInternal)
        public init() {}

        @MainActor
        private func resolve(_ selector: ModelSelector) -> (any AirshipAI.Model)? {
            switch selector {
            case .defaultModel: return defaultModelFactory?()
            case .custom(let m): return m
            }
        }

        @MainActor
        public var defaultModel: (any AirshipAI.Model)? {
            defaultModelFactory?()
        }

        @MainActor
        public func model<S: Sendable>(for usage: Usage<S>) -> (any AirshipAI.Model)? {
            let selector = overrideResolver?(AnyUsage(rawValue: usage.rawValue)) ?? .defaultModel
            return resolve(selector)
        }

        @MainActor
        public func setContextProvider<S: Sendable>(
            _ provider: (any ContextProvider<S>)?,
            for usage: Usage<S>
        ) {
            providerRegistry.setContextProvider(provider, for: usage)
        }

        @MainActor
        public func setDefaultContextProvider(_ provider: (any ContextProvider<Void>)?) {
            providerRegistry.setDefaultContextProvider(provider)
        }

        @MainActor
        public func setModelResolver(_ resolver: (@MainActor @Sendable (AnyUsage) -> ModelSelector)?) {
            overrideResolver = resolver
        }

        @MainActor
        public func registerModelFactory(
            _ factory: @MainActor @Sendable @escaping () -> any AirshipAI.Model
        ) {
            defaultModelFactory = factory
        }

        public func fetchContext<S: Sendable>(
            for usage: AirshipAI.Usage<S>,
            subject: S
        ) async -> AirshipAI.Context {
            await providerContext(forUsage: usage.rawValue, subject: subject)
        }

        public func evaluate<E: AirshipAI.Evaluation>(
            _ evaluation: E,
            context: AirshipAI.Context
        ) async -> AirshipAI.Result<E.Output> {
            guard let resolved = await resolve(evaluation) else {
                return .skipped(reason: "No model configured")
            }
            // Provider context first, then the caller's additional context appended after
            // (later items win priority ties when the model trims to fit its window).
            let merged = resolved.context.appending(context)
            return await evaluator.evaluate(evaluation, model: resolved.model, context: merged)
        }

        /// Resolves the model and fetches the provider's context in a single main-actor hop.
        /// The provider fetcher is main-actor-isolated, so staying on the actor across its
        /// async work avoids a second cross-actor round trip. Returns nil (skipping the
        /// context fetch) when no model is configured.
        @MainActor
        private func resolve<E: AirshipAI.Evaluation>(
            _ evaluation: E
        ) async -> (model: any AirshipAI.Model, context: AirshipAI.Context)? {
            guard let model = self.model(for: evaluation.usage) else { return nil }
            let context = await providerContext(
                forUsage: evaluation.usage.rawValue,
                subject: evaluation.subject
            )
            return (model, context)
        }

        /// Fetches the registered provider's context for a usage, or `.empty` when none is
        /// registered. Runs entirely on the main actor — the fetcher and its async work stay
        /// there, so callers pay a single hop.
        @MainActor
        private func providerContext(
            forUsage rawValue: String,
            subject: any Sendable
        ) async -> AirshipAI.Context {
            await providerRegistry.contextFetcher(for: rawValue)?(subject) ?? .empty
        }
    }
}
