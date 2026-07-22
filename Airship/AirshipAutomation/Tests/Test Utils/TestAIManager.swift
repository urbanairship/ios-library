/* Copyright Airship and Contributors */

import Foundation
@_spi(AirshipInternal) import AirshipCore

final class TestAIManager: AirshipAI.InternalManager, @unchecked Sendable {
    var availability: AirshipAI.Availability = .unavailable(reason: .missingModel)

    @MainActor
    var availabilityUpdates: AsyncStream<AirshipAI.Availability> {
        let availability = self.availability
        return AsyncStream { continuation in
            continuation.yield(availability)
            continuation.finish()
        }
    }

    func setProvider<S: Sendable>(_ provider: (any AirshipAI.ContextProvider<S>)?, for usage: AirshipAI.Usage<S>) {}
    func setDefaultProvider(_ provider: (any AirshipAI.ContextProvider<Void>)?) {}
    func setModel(_ selector: AirshipAI.ModelSelector) {}
    /// Test hook. Receives the (type-erased) evaluation and returns a type-erased
    /// `AirshipAI.Result<E.Output>`. Defaults to `.skipped` when unset.
    var onEvaluate: (@Sendable (any Sendable) async -> Any)?

    func evaluate<E: AirshipAI.Evaluation>(_ evaluation: E) async -> AirshipAI.Result<E.Output> {
        guard let onEvaluate else { return .skipped(reason: "test") }
        guard let result = await onEvaluate(evaluation) as? AirshipAI.Result<E.Output> else {
            return .skipped(reason: "test: unexpected result type")
        }
        return result
    }
    func registerModelFactory(_ factory: @MainActor @Sendable @escaping () -> any AirshipAI.Model) {}
    func fetchContext<S: Sendable>(for usage: AirshipAI.Usage<S>, subject: S) async -> AirshipAI.Context { .empty }
}
