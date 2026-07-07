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
        public func setProvider(
            _ provider: (any ContextProvider)?,
            for usage: Usage
        ) {
            providerRegistry.setProvider(provider, for: usage)
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
        public func schema(for usage: Usage) -> Schema? {
            schemaRegistry.schema(for: usage)
        }

        @MainActor
        public func setSchema(_ schema: Schema, for usage: Usage) {
            schemaRegistry.setSchema(schema, for: usage)
        }

        @MainActor
        public func registerModelFactory(
            _ factory: @MainActor @Sendable @escaping () -> any AirshipAI.Model
        ) {
            defaultModelFactory = factory
        }

        public func evaluate<E: AirshipAI.Evaluation>(
            _ evaluation: E
        ) async -> AirshipAI.Result<E.Output> {
            let (model, provider, schema) = await MainActor.run {
                (resolvedModel,
                 providerRegistry.provider(for: evaluation.usage),
                 schemaRegistry.schema(for: evaluation.usage))
            }
            guard let model else {
                return .skipped(reason: "No model configured")
            }
            guard let schema else {
                return .skipped(reason: "No schema registered for \(evaluation.usage)")
            }
            return await evaluator.evaluate(evaluation, model: model, provider: provider, schema: schema)
        }
    }
}
