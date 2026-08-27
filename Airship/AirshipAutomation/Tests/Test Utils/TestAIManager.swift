/* Copyright Airship and Contributors */

import Foundation
@_spi(AirshipInternal) import AirshipCore

final class TestAIManager: AirshipAI.InternalManager, @unchecked Sendable {
    var stubModel: (any AirshipAI.ModelProtocol)?

    var defaultModel: (any AirshipAI.ModelProtocol)? { nil }
    func model<S: Sendable>(for usage: AirshipAI.Usage<S>) -> (any AirshipAI.ModelProtocol)? { stubModel }
    func setContextProvider<S: Sendable>(for usage: AirshipAI.Usage<S>, _ provider: AirshipAI.ContextProvider<S>?) {}
    func setDefaultContextProvider(_ provider: (@Sendable () async -> AirshipAI.Context)?) {}
    func setEvaluationObserver(_ observer: AirshipAI.EvaluationObserver?) {}
    func setModelResolver(_ resolver: (@MainActor @Sendable (AirshipAI.AnyUsage) -> AirshipAI.ModelSelector)?) {}
    /// Test hook. Receives the (type-erased) evaluation and returns a type-erased
    /// `AirshipAI.Result<E.Output>`. Defaults to `.skipped` when unset.
    var onEvaluate: (@Sendable (any Sendable) async -> Any)?

    func evaluate<E: AirshipAI.Evaluation>(_ evaluation: E, additionalContext: AirshipAI.Context) async -> AirshipAI.Result<E.Output> {
        guard let onEvaluate else { return .skipped(reason: "test") }
        guard let result = await onEvaluate(evaluation) as? AirshipAI.Result<E.Output> else {
            return .skipped(reason: "test: unexpected result type")
        }
        return result
    }
    func registerModelFactory(_ factory: @MainActor @Sendable @escaping () -> any AirshipAI.ModelProtocol) {}
    func fetchContext<S: Sendable>(for usage: AirshipAI.Usage<S>, subject: S) async -> AirshipAI.Context { .empty }
    func gatedModel<S: Sendable>(for usage: AirshipAI.Usage<S>) -> (any AirshipAI.ModelProtocol)? { nil }
}
