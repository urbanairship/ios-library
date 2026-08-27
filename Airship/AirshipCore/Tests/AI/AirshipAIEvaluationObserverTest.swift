/* Copyright Airship and Contributors */

import Testing
import Foundation
@testable @_spi(AirshipInternal) import AirshipBasement
@testable @_spi(AirshipInternal) import AirshipCore

private enum ObserverTestError: Error { case boom }

/// The observer is the customer's only window into what the on-device model was asked and
/// what it answered, so the thing worth pinning down is that it fires for *every* outcome —
/// a model that never ran is the common case in the field and the one they most need to see.
@MainActor
struct AirshipAIEvaluationObserverTest {

    private struct Recorder: Sendable {
        let records = AirshipAtomicValue<[AirshipAI.EvaluationRecord]>([])

        var observer: AirshipAI.EvaluationObserver {
            { record in records.update { $0.append(record) } }
        }
    }

    /// Records arrive on a task of their own, so they land a turn after the evaluation
    /// returns rather than before it.
    private func waitForRecords(
        _ recorder: Recorder,
        count: Int,
        timeout: TimeInterval = 2
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while recorder.records.value.count < count {
            guard Date() < deadline else {
                struct Timeout: Error {}
                throw Timeout()
            }
            try await Task.sleep(nanoseconds: 2_000_000)
        }
    }

    /// Gives any stray record a chance to land, for the cases asserting none does.
    private func settle() async throws {
        try await Task.sleep(nanoseconds: 50_000_000)
    }

    private func evaluate(
        model: any AirshipAI.ModelProtocol,
        context: AirshipAI.Context = .empty,
        observer: AirshipAI.EvaluationObserver?
    ) async -> AirshipAI.Result<TestEvaluation.Output> {
        await AirshipAI.Evaluator().evaluate(
            TestEvaluation(),
            model: model,
            context: context,
            observer: observer
        )
    }

    @Test("A completed evaluation reports the raw output, before decoding")
    func completedReportsRawOutput() async throws {
        let recorder = Recorder()
        let model = MockAIModel(response: .success(["allow": true, "reason": "ok"]))

        _ = await evaluate(model: model, observer: recorder.observer)
        try await waitForRecords(recorder, count: 1)

        let records = recorder.records.value
        #expect(records.count == 1)
        guard case .completed(let output) = records.first?.outcome else {
            Issue.record("Expected .completed")
            return
        }
        // Raw JSON rather than a typed value is what lets one observer serve every usage.
        #expect(output.object?["reason"]?.string == "ok")
        #expect(records.first?.usage.rawValue == "test_usage")
        #expect(records.first?.attempts == 1)
    }

    @Test("An unavailable model still reports, so absence is visible")
    func unavailableModelReports() async throws {
        let recorder = Recorder()
        let model = MockAIModel(availability: .unavailable(reason: .missingModel))

        _ = await evaluate(model: model, observer: recorder.observer)
        try await waitForRecords(recorder, count: 1)

        let records = recorder.records.value
        #expect(records.count == 1)
        guard case .skipped(let reason) = records.first?.outcome else {
            Issue.record("Expected .skipped")
            return
        }
        #expect(reason == "Model unavailable")
        // Never reached the model, so nothing was attempted.
        #expect(records.first?.attempts == 0)
    }

    @Test("A failure reports, and counts the attempts it burned")
    func failureReportsAttempts() async throws {
        let recorder = Recorder()
        let model = MockAIModel(
            response: .failure(ObserverTestError.boom),
            maxAttempts: 3
        )

        _ = await evaluate(model: model, observer: recorder.observer)
        try await waitForRecords(recorder, count: 1)

        let records = recorder.records.value
        #expect(records.count == 1)
        guard case .failed = records.first?.outcome else {
            Issue.record("Expected .failed")
            return
        }
        #expect(records.first?.attempts == 3)
    }

    @Test("The record carries the request that was sent")
    func recordCarriesRequest() async throws {
        let recorder = Recorder()
        let model = MockAIModel()
        let context = AirshipAI.Context(items: [.init(content: "User interests: cats")])

        _ = await evaluate(model: model, context: context, observer: recorder.observer)
        try await waitForRecords(recorder, count: 1)

        let request = try #require(recorder.records.value.first?.request)
        #expect(request.instructions == "rules")
        // Context as offered — a model that trims to fit does so on its own copy.
        #expect(request.context.items.map(\.content) == ["User interests: cats"])
    }

    @Test("No observer registered is not an error")
    func noObserverIsFine() async {
        let result = await evaluate(model: MockAIModel(), observer: nil)
        guard case .completed = result else {
            Issue.record("Expected .completed")
            return
        }
    }

    @Test("The manager hands the observer to the evaluation")
    func managerForwardsObserver() async throws {
        let recorder = Recorder()
        let manager = makeObserverManager()
        manager.registerModelFactory { MockAIModel() }
        manager.setEvaluationObserver(recorder.observer)

        _ = await manager.evaluate(TestEvaluation())
        try await waitForRecords(recorder, count: 1)

        #expect(recorder.records.value.count == 1)
    }

    @Test("Clearing the observer stops the reports")
    func clearingObserverStops() async throws {
        let recorder = Recorder()
        let manager = makeObserverManager()
        manager.registerModelFactory { MockAIModel() }

        manager.setEvaluationObserver(recorder.observer)
        _ = await manager.evaluate(TestEvaluation())
        try await waitForRecords(recorder, count: 1)

        manager.setEvaluationObserver(nil)
        _ = await manager.evaluate(TestEvaluation())
        try await settle()

        #expect(recorder.records.value.count == 1)
    }

    private func makeObserverManager() -> AirshipAI.DefaultManager {
        AirshipAI.DefaultManager(
            privacyManager: TestPrivacyManager(
                dataStore: PreferenceDataStore(appKey: UUID().uuidString),
                config: RuntimeConfig.testConfig(),
                defaultEnabledFeatures: .all
            )
        )
    }
}
