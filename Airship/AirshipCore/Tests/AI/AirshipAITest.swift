/* Copyright Airship and Contributors */

import Testing
import Foundation
@testable @_spi(AirshipInternal) import AirshipCore

private enum SampleError: Error { case boom }

// MARK: - Value types

struct AirshipAIValueTests {

    @Test
    func resultOutputOnlyForCompleted() {
        #expect(AirshipAI.Result<Int>.completed(7).output == 7)
        #expect(AirshipAI.Result<Int>.skipped(reason: "nope").output == nil)
        #expect(AirshipAI.Result<Int>.failed(SampleError.boom).output == nil)
    }

    @Test
    func emptyContextIsEmpty() {
        let empty = AirshipAI.Context.empty
        #expect(empty.summary == nil)
        #expect(empty.attributes.isEmpty)
    }

    @Test
    func usageCodesAsBareString() throws {
        let data = try JSONEncoder().encode(AirshipAI.Usage.inAppMessageFilter)
        #expect(String(data: data, encoding: .utf8) == "\"in_app_message_filter\"")
        #expect(try JSONDecoder().decode(AirshipAI.Usage.self, from: data) == .inAppMessageFilter)
    }

    @Test
    func schemaInstructionListsFields() {
        let schema = AirshipAI.Schema(fields: [
            .init(name: "allow", type: .boolean, description: "whether to show"),
            .init(name: "reason", type: .string, isRequired: false)
        ])
        let instruction = schema.instruction
        #expect(instruction.contains("\"allow\": boolean (required) — whether to show"))
        #expect(instruction.contains("\"reason\": string (optional)"))
    }
}

// MARK: - Context provider registration

@MainActor
struct AirshipAIContextProviderTests {

    final class StubProvider: AirshipAI.ContextProvider, @unchecked Sendable {
        func context(for usage: AirshipAI.Usage) async -> AirshipAI.Context { .empty }
    }

    @Test
    func setProviderRegistersResolvesAndClears() throws {
        let manager = AirshipAI.DefaultManager()
        defer { manager.setProvider(nil, for: .inAppMessageFilter) }

        let provider = StubProvider()
        manager.setProvider(provider, for: .inAppMessageFilter)
        manager.setProvider(nil, for: .inAppMessageFilter)
    }
}

// MARK: - Evaluator

/// Reusable stub model. Records what it was asked and returns a canned JSON string.
final class MockAIModel: AirshipAI.Model, @unchecked Sendable {
    var availabilityValue: AirshipAI.Availability
    var response: Swift.Result<String, any Error>

    private(set) var respondCallCount = 0
    private(set) var lastInstructions: String?
    private(set) var lastPrompt: String?
    private(set) var lastSchema: AirshipAI.Schema?

    init(
        availability: AirshipAI.Availability = .available,
        response: Swift.Result<String, any Error> = .success(#"{"allow":true,"reason":"ok"}"#)
    ) {
        self.availabilityValue = availability
        self.response = response
    }

    var availability: AirshipAI.Availability { availabilityValue }

    func respond(
        instructions: String,
        prompt: String,
        schema: AirshipAI.Schema
    ) async throws -> String {
        respondCallCount += 1
        lastInstructions = instructions
        lastPrompt = prompt
        lastSchema = schema
        return try response.get()
    }
}

final class MockContextProvider: AirshipAI.ContextProvider, @unchecked Sendable {
    let stubContext: AirshipAI.Context
    private(set) var requestedUsages: [AirshipAI.Usage] = []

    init(_ context: AirshipAI.Context) { self.stubContext = context }

    @MainActor
    func context(for usage: AirshipAI.Usage) async -> AirshipAI.Context {
        requestedUsages.append(usage)
        return stubContext
    }
}

let testSchema = AirshipAI.Schema(fields: [
    .init(name: "allow", type: .boolean, description: "whether to allow"),
    .init(name: "reason", type: .string)
])

struct TestEvaluation: AirshipAI.Evaluation {
    struct Output: Decodable, Sendable, Equatable {
        let allow: Bool
        let reason: String
    }

    let usage: AirshipAI.Usage = .inAppMessageFilter
    func instructions() -> String { "rules" }
    func prompt(context: AirshipAI.Context) -> String {
        "subject|\(context.summary ?? "no-context")"
    }
}

@MainActor
struct AirshipAIEvaluatorTests {

    private func eval(
        model: any AirshipAI.Model,
        provider: (any AirshipAI.ContextProvider)? = nil
    ) async -> AirshipAI.Result<TestEvaluation.Output> {
        await AirshipAI.Evaluator().evaluate(
            TestEvaluation(),
            model: model,
            provider: provider,
            schema: testSchema
        )
    }

    @Test
    func completedWhenModelSucceeds() async throws {
        let model = MockAIModel(response: .success(#"{"allow":false,"reason":"not relevant"}"#))
        let provider = MockContextProvider(AirshipAI.Context(summary: "likes hiking"))

        let result = await eval(model: model, provider: provider)

        let decision = try #require(result.output)
        #expect(decision == TestEvaluation.Output(allow: false, reason: "not relevant"))

        #expect(provider.requestedUsages == [.inAppMessageFilter])
        #expect(model.lastInstructions == "rules")
        #expect(model.lastPrompt == "subject|likes hiking")
        #expect(model.lastSchema?.fields.count == 2)
    }

    @Test
    func skippedWhenModelUnavailable() async {
        let model = MockAIModel(availability: .unavailable(reason: .deviceNotEligible))
        let provider = MockContextProvider(.empty)

        let result = await eval(model: model, provider: provider)

        guard case .skipped = result else {
            Issue.record("Expected .skipped, got \(result)")
            return
        }
        #expect(model.respondCallCount == 0)
        #expect(provider.requestedUsages.isEmpty)
    }

    @Test
    func failedWhenModelThrows() async {
        let result = await eval(
            model: MockAIModel(response: .failure(SampleError.boom)),
            provider: MockContextProvider(.empty)
        )
        guard case .failed = result else {
            Issue.record("Expected .failed, got \(result)")
            return
        }
    }

    @Test
    func failedWhenResponseIsNotValidJSON() async {
        let result = await eval(model: MockAIModel(response: .success("not json")))
        guard case .failed = result else {
            Issue.record("Expected .failed on bad JSON, got \(result)")
            return
        }
    }

    @Test
    func usesEmptyContextWhenNoProvider() async throws {
        let model = MockAIModel()
        _ = await eval(model: model)
        #expect(model.lastPrompt == "subject|no-context")
    }

    @Test
    @MainActor
    func managerUsesConfiguredModel() async throws {
        let model = MockAIModel(response: .success(#"{"allow":false,"reason":"override"}"#))
        let manager = AirshipAI.DefaultManager()
        manager.setModel(.custom(model))
        manager.setSchema(testSchema, for: .inAppMessageFilter)

        let result = await manager.evaluate(TestEvaluation())

        #expect(result.output?.allow == false)
        #expect(model.respondCallCount == 1)
    }
}
