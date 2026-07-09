/* Copyright Airship and Contributors */

import Testing
import Foundation
@testable @_spi(AirshipInternal) import AirshipCore

private enum SampleError: Error { case boom }

// MARK: - Test usage

private extension AirshipAI.Usage where Subject == Void {
    static let testUsage = AirshipAI.Usage<Void>(rawValue: "test_usage")
}

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
        let usage = AirshipAI.Usage<Void>(rawValue: "in_app_message_filter")
        let data = try JSONEncoder().encode(usage)
        #expect(String(data: data, encoding: .utf8) == "\"in_app_message_filter\"")
        let decoded = try JSONDecoder().decode(AirshipAI.Usage<Void>.self, from: data)
        #expect(decoded == usage)
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

// MARK: - Schema (nested types + validation)

struct AirshipAISchemaTests {

    /// A schema exercising every field type, including a nested object and an array.
    private let schema = AirshipAI.Schema(fields: [
        .init(name: "allow", type: .boolean),
        .init(name: "reason", type: .string, isRequired: false),
        .init(name: "user", type: .object(fields: [
            .init(name: "age", type: .integer),
            .init(name: "tags", type: .array(element: .string), isRequired: false)
        ]), isRequired: false)
    ])

    // MARK: instruction

    @Test
    func instructionRendersNestedObjectAndArray() {
        let instruction = schema.instruction
        #expect(instruction.contains("\"user\": {"))
        #expect(instruction.contains("\"age\": integer (required)"))
        #expect(instruction.contains("array of string"))
    }

    // MARK: validate — happy paths

    @Test
    func validatePassesForConformingObject() throws {
        try schema.validate(.object([
            "allow": .bool(true),
            "reason": .string("relevant"),
            "user": .object([
                "age": .number(30),
                "tags": .array([.string("a"), .string("b")])
            ])
        ]))
    }

    @Test
    func validateAllowsAbsentOptionalFields() throws {
        // Only the required "allow" is present.
        try schema.validate(.object(["allow": .bool(false)]))
    }

    @Test
    func validateIgnoresExtraKeys() throws {
        try schema.validate(.object([
            "allow": .bool(true),
            "unexpected": .string("ignored")
        ]))
    }

    @Test
    func validateAcceptsWholeNumberForInteger() throws {
        try schema.validate(.object([
            "allow": .bool(true),
            "user": .object(["age": .number(42)])
        ]))
    }

    // MARK: validate — failures

    @Test
    func validateThrowsForMissingRequiredField() {
        #expect(throws: (any Error).self) {
            try schema.validate(.object(["reason": .string("no allow key")]))
        }
    }

    @Test
    func validateThrowsForWrongScalarType() {
        #expect(throws: (any Error).self) {
            try schema.validate(.object(["allow": .string("not a bool")]))
        }
    }

    @Test
    func validateThrowsForNonObjectRoot() {
        #expect(throws: (any Error).self) {
            try schema.validate(.string("not an object"))
        }
    }

    @Test
    func validateThrowsForBadNestedObjectField() {
        #expect(throws: (any Error).self) {
            try schema.validate(.object([
                "allow": .bool(true),
                "user": .object(["age": .string("thirty")])
            ]))
        }
    }

    @Test
    func validateThrowsForBadArrayElement() {
        #expect(throws: (any Error).self) {
            try schema.validate(.object([
                "allow": .bool(true),
                "user": .object([
                    "age": .number(30),
                    "tags": .array([.string("ok"), .number(5)])
                ])
            ]))
        }
    }

    @Test
    func validateThrowsForFractionalInteger() {
        #expect(throws: (any Error).self) {
            try schema.validate(.object([
                "allow": .bool(true),
                "user": .object(["age": .number(3.5)])
            ]))
        }
    }
}

// MARK: - Context provider registration

@MainActor
struct AirshipAIContextProviderTests {

    final class StubProvider: AirshipAI.ContextProvider, @unchecked Sendable {
        typealias Subject = Void
        func context(for subject: Void) async -> AirshipAI.Context { .empty }
    }

    @Test
    func setProviderRegistersResolvesAndClears() throws {
        let manager = AirshipAI.DefaultManager()
        defer { manager.setProvider(nil, for: .testUsage) }

        let provider = StubProvider()
        manager.setProvider(provider, for: .testUsage)
        manager.setProvider(nil, for: .testUsage)
    }
}

// MARK: - Evaluator

/// Reusable stub model. Records what it was asked and returns a canned JSON string.
final class MockAIModel: AirshipAI.Model, @unchecked Sendable {
    var availabilityValue: AirshipAI.Availability
    var response: Swift.Result<AirshipJSON, any Error>

    private(set) var respondCallCount = 0
    private(set) var lastInstructions: String?
    private(set) var lastPrompt: String?
    private(set) var lastSchema: AirshipAI.Schema?

    init(
        availability: AirshipAI.Availability = .available,
        response: Swift.Result<AirshipJSON, any Error> = .success(["allow": true, "reason": "ok"])
    ) {
        self.availabilityValue = availability
        self.response = response
    }

    var availability: AirshipAI.Availability { availabilityValue }

    func respond(
        instructions: String,
        prompt: String,
        schema: AirshipAI.Schema
    ) async throws -> AirshipJSON {
        respondCallCount += 1
        lastInstructions = instructions
        lastPrompt = prompt
        lastSchema = schema
        return try response.get()
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

    typealias Subject = Void

    let subject: Void = ()
    let usage: AirshipAI.Usage<Void> = .testUsage
    func instructions() -> String { "rules" }
    func prompt(context: AirshipAI.Context) -> String {
        "subject|\(context.summary ?? "no-context")"
    }
}

@MainActor
struct AirshipAIEvaluatorTests {

    private func eval(
        model: any AirshipAI.Model,
        context: AirshipAI.Context = .empty
    ) async -> AirshipAI.Result<TestEvaluation.Output> {
        await AirshipAI.Evaluator().evaluate(
            TestEvaluation(),
            model: model,
            context: context,
            schema: testSchema
        )
    }

    @Test
    func completedWhenModelSucceeds() async throws {
        let model = MockAIModel(response: .success(["allow": false, "reason": "not relevant"]))

        let result = await eval(
            model: model,
            context: AirshipAI.Context(summary: "likes hiking")
        )

        let decision = try #require(result.output)
        #expect(decision == TestEvaluation.Output(allow: false, reason: "not relevant"))
        #expect(model.lastInstructions == "rules")
        #expect(model.lastPrompt == "subject|likes hiking")
        #expect(model.lastSchema?.fields.count == 2)
    }

    @Test
    func skippedWhenModelUnavailable() async {
        let model = MockAIModel(availability: .unavailable(reason: .deviceNotEligible))

        let result = await eval(model: model)

        guard case .skipped = result else {
            Issue.record("Expected .skipped, got \(result)")
            return
        }
        #expect(model.respondCallCount == 0)
    }

    @Test
    func failedWhenModelThrows() async {
        let result = await eval(model: MockAIModel(response: .failure(SampleError.boom)))
        guard case .failed = result else {
            Issue.record("Expected .failed, got \(result)")
            return
        }
    }

    @Test
    func failedWhenResponseDoesNotMatchSchema() async {
        let result = await eval(model: MockAIModel(response: .success(["unexpected_key": "value"])))
        guard case .failed = result else {
            Issue.record("Expected .failed on schema mismatch, got \(result)")
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
        let model = MockAIModel(response: .success(["allow": false, "reason": "override"]))
        let manager = AirshipAI.DefaultManager()
        manager.setModel(.custom(model))
        manager.setSchema(testSchema, for: .testUsage)

        let result = await manager.evaluate(TestEvaluation())

        #expect(result.output?.allow == false)
        #expect(model.respondCallCount == 1)
    }
}
