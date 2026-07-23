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
            let contextFetcher = await MainActor.run {
                providerRegistry.contextFetcher(for: usage.rawValue)
            }
            return await contextFetcher?(subject) ?? .empty
        }

        public func evaluate<E: AirshipAI.Evaluation>(
            _ evaluation: E
        ) async -> AirshipAI.Result<E.Output> {
            let (model, contextFetcher) = await MainActor.run {
                (self.model(for: evaluation.usage),
                 providerRegistry.contextFetcher(for: evaluation.usage.rawValue))
            }
            guard let model else {
                return .skipped(reason: "No model configured")
            }
            // Provider context first, then the evaluation's own context appended after
            // (later items win priority ties when the model trims to fit its window).
            let providerContext = await contextFetcher?(evaluation.subject) ?? .empty
            let context = providerContext.appending(evaluation.additionalContext)
            return await evaluator.evaluate(evaluation, model: model, context: context)
        }
    }
}
