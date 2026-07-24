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
            .init(content: "b", priority: 2),
            .init(content: "a", priority: 0),
            .init(content: "", priority: 0)
        ])
        // Order preserved, empty content skipped, priority never rendered.
        #expect(context.render() == "b\na")
    }

    @Test
    func droppingLowestPriorityItemDropsEarliestLeastImportant() {
        // Lower value is more important, so the highest value is dropped first.
        let context = AirshipAI.Context(items: [
            .init(content: "keep-important", priority: 0),
            .init(content: "drop-first", priority: 2),
            .init(content: "drop-second", priority: 2),
            .init(content: "keep-mid", priority: 1)
        ])

        var trimmed = context
        #expect(trimmed.dropLowestPriorityItem()?.content == "drop-first")
        #expect(trimmed.items.map(\.content) == ["keep-important", "drop-second", "keep-mid"])

        #expect(trimmed.dropLowestPriorityItem()?.content == "drop-second")
        #expect(trimmed.items.map(\.content) == ["keep-important", "keep-mid"])

        #expect(trimmed.dropLowestPriorityItem()?.content == "keep-mid")
        #expect(trimmed.items.map(\.content) == ["keep-important"])

        var empty = AirshipAI.Context.empty
        #expect(empty.dropLowestPriorityItem() == nil)
    }

    @Test
    func appendingKeepsOrderWithOtherItemsLast() {
        // Same value → the appended (later) item is dropped last, so it wins the tie.
        let base = AirshipAI.Context(items: [.init(content: "provider", priority: 1)])
        let merged = base.appending(
            AirshipAI.Context(items: [.init(content: "authored", priority: 1)])
        )
        #expect(merged.items.map(\.content) == ["provider", "authored"])
        var trimmed = merged
        #expect(trimmed.dropLowestPriorityItem()?.content == "provider")
        #expect(trimmed.items.map(\.content) == ["authored"])
        #expect(base.appending(.empty) == base)
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
    func validateThrowsForMissingRequiredKeyNotInProperties() throws {
        // `required` may name a key that has no entry in `properties` — its
        // presence must still be enforced.
        let schema = AirshipJSONSchema.object(
            properties: ["known": .string()],
            required: ["mustExist"]
        )
        #expect(throws: (any Error).self) {
            try schema.validate(.object(["known": .string("here")]))
        }
        try schema.validate(.object([
            "known": .string("here"),
            "mustExist": .string("present")
        ]))
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
        #expect(info.properties?["result"]?.type == .string(.init(choices: ["a", "b"])))
        #expect(info.properties?["reason"]?.type == .string(.init()))
        #expect(info.properties?["reason"]?.description == "why")
        #expect(info.required == ["result"])
    }

    @Test
    func decodesObjectWithoutProperties() throws {
        // `properties` is optional per JSON Schema — an object node may omit it.
        let json = """
        {"type": "object", "required": ["anything"]}
        """
        let schema = try JSONDecoder().decode(AirshipJSONSchema.self, from: Data(json.utf8))
        guard case .object(let info) = schema.type else {
            Issue.record("Expected object type")
            return
        }
        #expect(info.properties == nil)
        // No declared properties → any object is accepted, but `required` still applies.
        try schema.validate(.object(["anything": .string("present"), "extra": .bool(true)]))
        #expect(throws: (any Error).self) {
            try schema.validate(.object(["missing": .string("required key")]))
        }
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

    // MARK: vendor extensions (x-*)

    @Test
    func decodesVendorExtensionKeysAtEveryLevel() throws {
        let json = """
        {
          "type": "object",
          "x-ua-report": true,
          "properties": {
            "result": {"type": "string", "x-ua-report-property": true},
            "reason": {"type": "string"}
          }
        }
        """
        let schema = try JSONDecoder().decode(AirshipJSONSchema.self, from: Data(json.utf8))
        #expect(schema.extensions["x-ua-report"] == .bool(true))

        guard case .object(let info) = schema.type else {
            Issue.record("Expected object type")
            return
        }
        #expect(info.properties?["result"]?.extensions["x-ua-report-property"] == .bool(true))
        #expect(info.properties?["reason"]?.extensions.isEmpty == true)
    }

    @Test
    func decodeCapturesOnlyVendorPrefixedUnknownKeys() throws {
        // `x-*` is captured; other unknown keys are still ignored (dropped).
        let json = """
        {"type": "string", "x-keep": 1, "randomUnknown": "dropped"}
        """
        let schema = try JSONDecoder().decode(AirshipJSONSchema.self, from: Data(json.utf8))
        #expect(schema.extensions == ["x-keep": .number(1)])
    }

    @Test
    func extensionsRoundTripThroughCodable() throws {
        let json = """
        {
          "type": "object",
          "x-ua-report": true,
          "properties": {
            "result": {"type": "string", "x-ua-report-property": true}
          }
        }
        """
        let decoded = try JSONDecoder().decode(AirshipJSONSchema.self, from: Data(json.utf8))
        let reDecoded = try JSONDecoder().decode(
            AirshipJSONSchema.self,
            from: JSONEncoder().encode(decoded)
        )
        // Equatable now compares extensions, so this also proves encode wrote them back
        // without clobbering a real keyword.
        #expect(reDecoded == decoded)
        #expect(reDecoded.extensions["x-ua-report"] == .bool(true))
    }

    @Test
    func initKeepsOnlyVendorExtensionKeys() {
        let schema = AirshipJSONSchema(
            type: .string(.init()),
            extensions: ["x-ok": .bool(true), "nope": .string("dropped")]
        )
        #expect(schema.extensions == ["x-ok": .bool(true)])
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
    func scalarRootValidates() throws {
        let schema = AirshipJSONSchema.string(choices: ["a", "b"])

        try schema.validate(.string("a"))
        #expect(throws: (any Error).self) {
            try schema.validate(.string("c"))
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
    func setContextProviderRegistersResolvesAndClears() throws {
        let manager = AirshipAI.DefaultManager()
        defer { manager.setContextProvider(nil, for: .testUsage) }

        let provider = StubProvider()
        manager.setContextProvider(provider, for: .testUsage)
        manager.setContextProvider(nil, for: .testUsage)
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
    private(set) var lastRequest: AirshipAI.Request?

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

    func respond(_ request: AirshipAI.Request) async throws -> AirshipJSON {
        respondCallCount += 1
        lastRequest = request
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
    func prompt(context: AirshipAI.Context) -> String { "subject" }
}


/// Context provider returning a fixed set of items.
final class ItemsProvider: AirshipAI.ContextProvider, @unchecked Sendable {
    typealias Subject = Void
    let items: [AirshipAI.Context.Item]
    init(_ items: [AirshipAI.Context.Item]) { self.items = items }
    func context(for subject: Void) async -> AirshipAI.Context { .init(items: items) }
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
        let context = AirshipAI.Context(items: [.init(content: "likes hiking", priority: 0)])

        let result = await eval(model: model, context: context)

        let decision = try #require(result.output)
        #expect(decision == TestEvaluation.Output(allow: false, reason: "not relevant"))
        #expect(model.lastRequest?.instructions == "rules")
        #expect(model.lastRequest?.prompt() == "subject")
        #expect(model.lastRequest?.context == context)
        #expect(model.lastRequest?.schema == testSchema)
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
        #expect(model.lastRequest?.context == .empty)
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
    func cancellationErrorIsNotRetried() async {
        let model = MockAIModel(response: .failure(CancellationError()), maxAttempts: 5)

        let result = await eval(model: model)

        guard case .failed = result else {
            Issue.record("Expected .failed on CancellationError, got \(result)")
            return
        }
        // CancellationError must propagate immediately — not count as a retryable failure.
        // Without the catch-is-CancellationError branch, all 5 attempts would run.
        #expect(model.respondCallCount == 1)
    }

    @Test
    func retriesUpToMaxAttemptsOnOrdinaryFailure() async {
        let model = MockAIModel(response: .failure(SampleError.boom), maxAttempts: 3)

        let result = await eval(model: model)

        guard case .failed = result else {
            Issue.record("Expected .failed after exhausting attempts, got \(result)")
            return
        }
        #expect(model.respondCallCount == 3)
    }

    @Test
    func timeoutTerminatesSlowModel() async {
        let model = MockAIModel(responseTimeout: 0.1)
        model.respondDelay = 60  // model would hang for 60s without the timeout

        let start = ContinuousClock.now
        let result = await eval(model: model)
        let elapsed = ContinuousClock.now - start

        guard case .failed = result else {
            Issue.record("Expected .failed on timeout, got \(result)")
            return
        }
        // If cancellation leaked and the operation task wasn't cut off, this
        // would take the full 60s. Allow 5s of headroom for slow CI runners.
        #expect(elapsed < .seconds(5))
    }

    @Test
    @MainActor
    func managerUsesConfiguredModel() async throws {
        let model = MockAIModel(response: .success(["allow": false, "reason": "override"]))
        let manager = AirshipAI.DefaultManager()
        manager.setModelResolver { _ in .custom(model) }

        let result = await manager.evaluate(TestEvaluation())

        #expect(result.output?.allow == false)
        #expect(model.respondCallCount == 1)
    }

    @Test
    @MainActor
    func managerAppendsAdditionalContextAfterProviderContext() async {
        let model = MockAIModel()
        let manager = AirshipAI.DefaultManager()
        manager.setModelResolver { _ in .custom(model) }
        manager.setContextProvider(
            ItemsProvider([.init(content: "provider", priority: 0)]),
            for: .testUsage
        )
        defer { manager.setContextProvider(nil, for: .testUsage) }

        _ = await manager.evaluate(
            TestEvaluation(),
            context: .init(items: [.init(content: "authored", priority: 5)])
        )

        #expect(model.lastRequest?.context.items.map(\.content) == ["provider", "authored"])
    }
}

// MARK: - Manager per-usage model resolution

@MainActor
struct AirshipAIManagerModelTests {

    @Test
    func modelReturnsNilWhenNoneConfigured() {
        let manager = AirshipAI.DefaultManager()
        #expect(manager.model(for: AirshipAI.Usage<Void>(rawValue: "test")) == nil)
    }

    @Test
    func modelReturnsDefaultFactoryModelWhenNoOverride() {
        let model = MockAIModel(availability: .available)
        let manager = AirshipAI.DefaultManager()
        manager.registerModelFactory { model }

        let resolved = manager.model(for: AirshipAI.Usage<Void>(rawValue: "any_usage"))
        #expect(resolved?.availability == .available)
    }

    @Test
    func overrideResolverWinsOverDefaultFactory() {
        let defaultModel = MockAIModel(availability: .available)
        let usageModel = MockAIModel(availability: .unavailable(reason: .notEnabled))
        let manager = AirshipAI.DefaultManager()
        manager.registerModelFactory { defaultModel }
        manager.setModelResolver { usage in
            usage == AirshipAI.Usage<Void>.testUsage ? .custom(usageModel) : .defaultModel
        }

        #expect(manager.model(for: .testUsage)?.availability == .unavailable(reason: .notEnabled))
        #expect(manager.model(for: AirshipAI.Usage<Void>(rawValue: "other"))?.availability == .available)
    }

    @Test
    func clearingOverrideResolverFallsBackToDefaultFactory() {
        let defaultModel = MockAIModel(availability: .available)
        let usageModel = MockAIModel(availability: .unavailable(reason: .notEnabled))
        let manager = AirshipAI.DefaultManager()
        manager.registerModelFactory { defaultModel }
        manager.setModelResolver { _ in .custom(usageModel) }
        manager.setModelResolver(nil)

        #expect(manager.model(for: .testUsage)?.availability == .available)
    }
}
