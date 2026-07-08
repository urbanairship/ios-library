/* Copyright Airship and Contributors */

import Foundation

extension AirshipAI {
    final class DefaultManager: InternalManager, Sendable {

        @MainActor
        private var currentSelector: ModelSelector = .defaultModel

        @MainActor
        private var defaultModelFactory: (@MainActor @Sendable () -> any AirshipAI.Model)?

        @MainActor
        private let providerRegistry = ProviderRegistry()

        @MainActor
        private let schemaRegistry = SchemaRegistry()

        private let evaluator = AirshipAI.Evaluator()

        @_spi(AirshipInternal)
        public init() {}

        @MainActor
        private var resolvedModel: (any AirshipAI.Model)? {
            switch currentSelector {
            case .defaultModel:
                return defaultModelFactory?()
            case .custom(let m):
                return m
            }
        }

        @MainActor
        public func setProvider<S: Sendable>(
            _ provider: (any ContextProvider<S>)?,
            for usage: Usage<S>
        ) {
            providerRegistry.setProvider(provider, for: usage)
        }

        @MainActor
        public func setDefaultProvider(_ provider: (any ContextProvider<Void>)?) {
            providerRegistry.setDefaultProvider(provider)
        }

        @MainActor
        public func setModel(_ selector: ModelSelector) {
            currentSelector = selector
        }

        @MainActor
        public var availability: Availability {
            resolvedModel?.availability ?? .unavailable(reason: .osVersion)
        }

        @MainActor
        public func schema<S: Sendable>(for usage: Usage<S>) -> Schema? {
            schemaRegistry.schema(for: usage.rawValue)
        }

        @MainActor
        public func setSchema<S: Sendable>(_ schema: Schema, for usage: Usage<S>) {
            schemaRegistry.setSchema(schema, for: usage)
        }

        public var registeredUsageKeys: [String] {
            schemaRegistry.registeredUsageKeys
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
            let (model, contextFetcher, schema) = await MainActor.run {
                (resolvedModel,
                 providerRegistry.contextFetcher(for: evaluation.usage.rawValue),
                 schemaRegistry.schema(for: evaluation.usage.rawValue))
            }
            guard let model else {
                return .skipped(reason: "No model configured")
            }
            guard let schema else {
                return .skipped(reason: "No schema registered for \(evaluation.usage.rawValue)")
            }
            let context = await contextFetcher?(evaluation.subject) ?? .empty
            return await evaluator.evaluate(evaluation, model: model, context: context, schema: schema)
        }
    }
}
