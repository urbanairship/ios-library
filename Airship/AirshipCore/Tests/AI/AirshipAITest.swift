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
        #expect(empty.items.isEmpty)
        #expect(empty.render() == nil)
    }

    @Test
    func contextRenderJoinsItemsInOrderWithoutPriorities() {
        let context = AirshipAI.Context(items: [
            .init(content: "b", priority: .low),
            .init(content: "a", priority: .high),
            .init(content: "", priority: .high)
        ])
        // Order preserved, empty content skipped, priority never rendered.
        #expect(context.render() == "b\na")
    }

    @Test
    func droppingLowestPriorityItemDropsEarliestLowest() {
        let context = AirshipAI.Context(items: [
            .init(content: "keep-high", priority: .high),
            .init(content: "drop-first", priority: .low),
            .init(content: "drop-second", priority: .low),
            .init(content: "keep-medium", priority: .medium)
        ])

        let once = context.droppingLowestPriorityItem()
        #expect(once?.items.map(\.content) == ["keep-high", "drop-second", "keep-medium"])

        let twice = once?.droppingLowestPriorityItem()
        #expect(twice?.items.map(\.content) == ["keep-high", "keep-medium"])

        let thrice = twice?.droppingLowestPriorityItem()
        #expect(thrice?.items.map(\.content) == ["keep-high"])

        #expect(AirshipAI.Context.empty.droppingLowestPriorityItem() == nil)
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
        let schema = AirshipJSONSchema.object(
            properties: [
                "allow": .boolean(description: "whether to show"),
                "reason": .string()
            ],
            required: ["allow"]
        )
        let instruction = schema.instruction
        #expect(instruction.contains("\"allow\": boolean (required) — whether to show"))
        #expect(instruction.contains("\"reason\": string (optional)"))
    }
}

// MARK: - Schema (nested types + validation)

struct AirshipAISchemaTests {

    /// A schema exercising every value type, including a nested object and an array.
    private let schema = AirshipJSONSchema.object(
        properties: [
            "allow": .boolean(),
            "reason": .string(),
            "user": .object(
                properties: [
                    "age": .integer(),
                    "tags": .array(items: .string())
                ],
                required: ["age"]
            )
        ],
        required: ["allow"]
    )

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

    // MARK: string enum

    private let enumSchema = AirshipJSONSchema.object(
        properties: [
            "result": .string(choices: ["shipping", "quality", "praise"])
        ],
        required: ["result"]
    )

    @Test
    func instructionRendersEnumChoices() {
        #expect(enumSchema.instruction.contains(
            "\"result\": string, exactly one of: \"shipping\", \"quality\", \"praise\" (required)"
        ))
    }

    @Test
    func validateAcceptsEnumMember() throws {
        try enumSchema.validate(.object(["result": .string("quality")]))
    }

    @Test
    func validateThrowsForNonEnumMember() {
        #expect(throws: (any Error).self) {
            try enumSchema.validate(.object(["result": .string("pricing")]))
        }
    }

    @Test
    func validateThrowsForNonStringEnumValue() {
        #expect(throws: (any Error).self) {
            try enumSchema.validate(.object(["result": .number(4)]))
        }
    }

    // MARK: Codable

    @Test
    func decodesJSONSchemaStyleObject() throws {
        let json = """
        {
          "type": "object",
          "properties": {
            "result": {"type": "string", "enum": ["a", "b"]},
            "reason": {"type": "string", "description": "why"}
          },
          "required": ["result"]
        }
        """
        let schema = try JSONDecoder().decode(AirshipJSONSchema.self, from: Data(json.utf8))
        guard case .object(let info) = schema.type else {
            Issue.record("Expected object type")
            return
        }
        #expect(info.properties["result"]?.type == .string(.init(choices: ["a", "b"])))
        #expect(info.properties["reason"]?.type == .string(.init()))
        #expect(info.properties["reason"]?.description == "why")
        #expect(info.required == ["result"])
    }

    @Test
    func schemaRoundTripsThroughCodable() throws {
        let original = AirshipJSONSchema.object(
            properties: [
                "result": .string(choices: ["a", "b"], description: "pick one"),
                "tags": .array(items: .string()),
                "details": .object(
                    properties: ["score": .number()],
                    required: ["score"]
                )
            ],
            required: ["result", "details"]
        )
        let decoded = try JSONDecoder().decode(
            AirshipJSONSchema.self,
            from: JSONEncoder().encode(original)
        )
        #expect(decoded == original)
    }

    // MARK: Non-object roots

    @Test
    func decodesScalarEnumRoot() throws {
        let json = """
        {"type": "string", "enum": ["shipping", "quality"]}
        """
        let schema = try JSONDecoder().decode(AirshipJSONSchema.self, from: Data(json.utf8))
        #expect(schema == .string(choices: ["shipping", "quality"]))
    }

    @Test
    func arrayRootRoundTripsAndValidates() throws {
        let original = AirshipJSONSchema.array(items: .string())
        let decoded = try JSONDecoder().decode(
            AirshipJSONSchema.self,
            from: JSONEncoder().encode(original)
        )
        #expect(decoded == original)

        try decoded.validate(.array([.string("a"), .string("b")]))
        #expect(throws: (any Error).self) {
            try decoded.validate(.object(["not": .string("an array")]))
        }
    }

    @Test
    func scalarRootValidatesAndRendersInstruction() throws {
        let schema = AirshipJSONSchema.string(choices: ["a", "b"])

        try schema.validate(.string("a"))
        #expect(throws: (any Error).self) {
            try schema.validate(.string("c"))
        }

        #expect(schema.instruction.contains("single JSON value"))
        #expect(schema.instruction.contains("exactly one of: \"a\", \"b\""))
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

/// Reusable stub model. Records what it was asked and returns canned responses —
/// one per attempt when `responses` holds several, repeating the last.
final class MockAIModel: AirshipAI.Model, @unchecked Sendable {
    var availabilityValue: AirshipAI.Availability
    var responses: [Swift.Result<AirshipJSON, any Error>]
    var maxAttempts: Int
    var responseTimeout: TimeInterval
    var respondDelay: TimeInterval = 0

    private(set) var respondCallCount = 0
    private(set) var lastInstructions: String?
    private(set) var lastPrompt: String?
    private(set) var lastContext: AirshipAI.Context?
    private(set) var lastSchema: AirshipJSONSchema?

    init(
        availability: AirshipAI.Availability = .available,
        response: Swift.Result<AirshipJSON, any Error> = .success(["allow": true, "reason": "ok"]),
        maxAttempts: Int = 1,
        responseTimeout: TimeInterval = 5
    ) {
        self.availabilityValue = availability
        self.responses = [response]
        self.maxAttempts = maxAttempts
        self.responseTimeout = responseTimeout
    }

    var availability: AirshipAI.Availability { availabilityValue }

    func respond(
        instructions: String,
        prompt: String,
        context: AirshipAI.Context,
        schema: AirshipJSONSchema
    ) async throws -> AirshipJSON {
        respondCallCount += 1
        lastInstructions = instructions
        lastPrompt = prompt
        lastContext = context
        lastSchema = schema
        if respondDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(respondDelay * 1_000_000_000))
        }
        let response = responses.count > 1 ? responses.removeFirst() : responses[0]
        return try response.get()
    }
}

let testSchema = AirshipJSONSchema.object(
    properties: [
        "allow": .boolean(description: "whether to allow"),
        "reason": .string()
    ],
    required: ["allow", "reason"]
)

struct TestEvaluation: AirshipAI.Evaluation {
    struct Output: Decodable, Sendable, Equatable {
        let allow: Bool
        let reason: String
    }

    typealias Subject = Void

    let subject: Void = ()
    let usage: AirshipAI.Usage<Void> = .testUsage
    let schema = testSchema
    func instructions() -> String { "rules" }
    func prompt() -> String { "subject" }
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
            context: context
        )
    }

    @Test
    func completedWhenModelSucceeds() async throws {
        let model = MockAIModel(response: .success(["allow": false, "reason": "not relevant"]))
        let context = AirshipAI.Context(items: [.init(content: "likes hiking", priority: .high)])

        let result = await eval(model: model, context: context)

        let decision = try #require(result.output)
        #expect(decision == TestEvaluation.Output(allow: false, reason: "not relevant"))
        #expect(model.lastInstructions == "rules")
        #expect(model.lastPrompt == "subject")
        #expect(model.lastContext == context)
        #expect(model.lastSchema == testSchema)
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
        let model = MockAIModel(response: .success(["unexpected_key": "value"]))
        let result = await eval(model: model)
        guard case .failed = result else {
            Issue.record("Expected .failed on schema mismatch, got \(result)")
            return
        }
    }

    @Test
    func usesEmptyContextWhenNoProvider() async throws {
        let model = MockAIModel()
        _ = await eval(model: model)
        #expect(model.lastContext == .empty)
    }

    // MARK: retry / timeout

    @Test
    func retriesUntilOutputConformsToSchema() async throws {
        let model = MockAIModel(maxAttempts: 3)
        model.responses = [
            .success(["unexpected_key": "value"]),
            .success(["allow": true, "reason": "second try"])
        ]

        let result = await eval(model: model)

        #expect(result.output == TestEvaluation.Output(allow: true, reason: "second try"))
        #expect(model.respondCallCount == 2)
    }

    @Test
    func failsAfterExhaustingAttempts() async {
        let model = MockAIModel(response: .success(["unexpected_key": "value"]), maxAttempts: 2)

        let result = await eval(model: model)

        guard case .failed = result else {
            Issue.record("Expected .failed after exhausting attempts, got \(result)")
            return
        }
        #expect(model.respondCallCount == 2)
    }

    @Test
    func failsWhenResponseTimeoutExpires() async {
        let model = MockAIModel(responseTimeout: 0.05)
        model.respondDelay = 5

        let result = await eval(model: model)

        guard case .failed = result else {
            Issue.record("Expected .failed on timeout, got \(result)")
            return
        }
    }

    @Test
    @MainActor
    func managerUsesConfiguredModel() async throws {
        let model = MockAIModel(response: .success(["allow": false, "reason": "override"]))
        let manager = AirshipAI.DefaultManager()
        manager.setModel(.custom(model))

        let result = await manager.evaluate(TestEvaluation())

        #expect(result.output?.allow == false)
        #expect(model.respondCallCount == 1)
    }
}
