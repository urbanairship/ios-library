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

        private let evaluator = AirshipAI.Evaluator()

        /// Live subscribers to `availabilityUpdates`, keyed so each can remove itself on
        /// termination.
        @MainActor
        private var availabilityContinuations: [UUID: AsyncStream<Availability>.Continuation] = [:]

        /// Forwards the currently resolved model's own availability changes into the
        /// broadcast. Cancelled and restarted whenever the resolved model changes.
        @MainActor
        private var modelObservationTask: Task<Void, Never>?

        /// Last value broadcast, so repeated equal values are collapsed.
        @MainActor
        private var lastBroadcastAvailability: Availability?

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
            restartModelObservation()
        }

        @MainActor
        public var availability: Availability {
            resolvedModel?.availability ?? .unavailable(reason: .missingModel)
        }

        @MainActor
        public func registerModelFactory(
            _ factory: @MainActor @Sendable @escaping () -> any AirshipAI.Model
        ) {
            defaultModelFactory = factory
            restartModelObservation()
        }

        @MainActor
        public var availabilityUpdates: AsyncStream<Availability> {
            AsyncStream { continuation in
                let id = UUID()
                continuation.yield(self.availability)
                self.availabilityContinuations[id] = continuation
                continuation.onTermination = { @Sendable _ in
                    Task { @MainActor in self.availabilityContinuations[id] = nil }
                }
            }
        }

        /// Recomputes availability and pushes it to all subscribers, collapsing repeats.
        @MainActor
        private func broadcastAvailability() {
            let current = self.availability
            guard current != lastBroadcastAvailability else { return }
            lastBroadcastAvailability = current
            for continuation in availabilityContinuations.values {
                continuation.yield(current)
            }
        }

        /// Re-subscribes to the resolved model's availability stream (and broadcasts the
        /// new current value). Called whenever the resolved model may have changed.
        @MainActor
        private func restartModelObservation() {
            modelObservationTask?.cancel()

            guard let model = resolvedModel else {
                broadcastAvailability()
                modelObservationTask = nil
                return
            }

            modelObservationTask = Task { @MainActor [weak self] in
                for await _ in model.availabilityUpdates {
                    if Task.isCancelled { return }
                    self?.broadcastAvailability()
                }
            }
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
                (resolvedModel,
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
