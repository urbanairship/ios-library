/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable @_spi(AirshipInternal) import AirshipCore
@testable @_spi(AirshipInternal) import AirshipSceneRenderer
@testable @_spi(AirshipInternal) import AirshipScenes

struct AirshipExtensionsTest {

    private let date: Date = Date.now

    @Test
    func commercialToContactOptions() throws {
        let options: ThomasEmailRegistrationOption = .commercial(
            ThomasEmailRegistrationOption.Commercial(
                optedIn: true,
                properties: try AirshipJSON.wrap(["cool": "prop"])
            )
        )

        let expected = EmailRegistrationOptions.commercialOptions(
            transactionalOptedIn: nil,
            commercialOptedIn: date,
            properties: ["cool": "prop"]
        )
        #expect(options.makeContactOptions(date: date) == expected)
    }

    @Test
    func commercialNoPropertiesToContactOptions() {
        let options: ThomasEmailRegistrationOption = .commercial(
            ThomasEmailRegistrationOption.Commercial(
                optedIn: false,
                properties: nil
            )
        )

        let expected = EmailRegistrationOptions.commercialOptions(
            transactionalOptedIn: nil,
            commercialOptedIn: nil,
            properties: nil
        )
        #expect(options.makeContactOptions(date: date) == expected)
    }

    @Test
    func transactionalToContactOptions() throws {
        let options: ThomasEmailRegistrationOption = .transactional(
            ThomasEmailRegistrationOption.Transactional(
                properties: try AirshipJSON.wrap(["cool": "prop"])
            )
        )

        let expected = EmailRegistrationOptions.options(
            transactionalOptedIn: nil,
            properties: ["cool": "prop"],
            doubleOptIn: false
        )
        #expect(options.makeContactOptions(date: date) == expected)
    }

    @Test
    func transactionalNoPropertiesToContactOptions() {
        let options: ThomasEmailRegistrationOption = .transactional(
            ThomasEmailRegistrationOption.Transactional(
                properties: nil
            )
        )

        let expected = EmailRegistrationOptions.options(
            transactionalOptedIn: nil,
            properties: nil,
            doubleOptIn: false
        )
        #expect(options.makeContactOptions(date: date) == expected)
    }

    @Test
    func doubleOptInToContactOptions() throws {
        let options: ThomasEmailRegistrationOption = .doubleOptIn(
            ThomasEmailRegistrationOption.DoubleOptIn(
                properties: try AirshipJSON.wrap(["cool": "prop"])
            )
        )

        let expected = EmailRegistrationOptions.options(properties: ["cool": "prop"], doubleOptIn: true)
        #expect(options.makeContactOptions(date: date) == expected)
    }

    @Test
    func doubleOptInNoPropertiesToContactOptions() {
        let options: ThomasEmailRegistrationOption = .doubleOptIn(
            ThomasEmailRegistrationOption.DoubleOptIn(
                properties: nil
            )
        )

        let expected = EmailRegistrationOptions.options(properties: nil, doubleOptIn: true)
        #expect(options.makeContactOptions(date: date) == expected)
    }

}

struct ThomasAIInferenceEvaluationGuardTest {

    private static let testSchema = AirshipJSONSchema.string(choices: ["positive", "negative"])

    private func makeEvaluation(prompt: String = "classify sentiment", text: String) -> ThomasAIInferenceEvaluation {
        ThomasAIInferenceEvaluation(request: .init(prompt: prompt, text: text, outputSchema: Self.testSchema))
    }

    @Test("User text is fenced inside XML tags in the prompt")
    func promptFencesUserText() {
        let eval = makeEvaluation(text: "I love it")
        let prompt = eval.prompt(context: .empty)
        #expect(prompt.contains("I love it"))
        #expect(prompt.contains("<\(eval.inputTag)>"))
        #expect(prompt.contains("</\(eval.inputTag)>"))
    }

    @Test("Instructions reference the tag and guard against embedded instructions")
    func instructionsGuardAgainstInjection() {
        let eval = makeEvaluation(prompt: "classify sentiment", text: "x")
        let instructions = eval.instructions()
        #expect(instructions.contains(eval.inputTag))
        #expect(instructions.contains("untrusted"))
        // The author's instruction drives the role.
        #expect(instructions.contains("classify sentiment"))
    }

    @Test("User text appears before background context in the combined prompt")
    func promptPutsUserTextFirst() {
        let eval = makeEvaluation(text: "I love it")
        let context = AirshipAI.Context(items: [.init(content: "Name: Alice")])
        let combined = eval.prompt(context: context)
        let inputRange = combined.range(of: "<\(eval.inputTag)>")!
        let contextRange = combined.range(of: "User context:")!
        #expect(inputRange.lowerBound < contextRange.lowerBound)
        #expect(combined.contains("- Name: Alice"))
    }

    @Test("The tag is regenerated per evaluation so it can't be guessed/injected")
    func tagRegeneratesPerEvaluation() {
        #expect(makeEvaluation(text: "x").inputTag != makeEvaluation(text: "x").inputTag)
    }
}

struct EmbeddedSelectionEvaluationTest {

    private func candidate(
        _ id: String,
        extras: AirshipJSON? = nil,
        priority: Int = 0,
        contentDescription: String? = nil,
        additionalContext: [ThomasAIContextItem] = []
    ) -> AirshipEmbeddedInfo {
        AirshipEmbeddedInfo(
            instanceID: id,
            embeddedID: "slot",
            extras: extras,
            priority: priority,
            contentDescription: contentDescription,
            additionalContext: additionalContext
        )
    }

    private func makeEvaluation(
        prompt: String = "pick the best offer",
        strategy: AirshipEmbeddedSelection.AIConfig.Strategy = .scoreThenPriority,
        minScoreThreshold: Int? = nil,
        candidates: [AirshipEmbeddedInfo]
    ) -> EmbeddedSelectionEvaluation {
        EmbeddedSelectionEvaluation(
            request: .init(
                embeddedID: "slot",
                prompt: prompt,
                strategy: strategy,
                minScoreThreshold: minScoreThreshold,
                candidates: candidates
            )
        )
    }

    @Test("Schema constrains scores to candidate ids")
    func schemaConstrainsScoresToCandidateIDs() throws {
        let eval = makeEvaluation(candidates: [
            candidate("a"),
            candidate("b"),
        ])

        guard case .object(let info) = eval.schema.type,
              case .array(let arrayInfo)? = info.properties?["scores"]?.type,
              case .object(let itemInfo) = arrayInfo.items.type,
              case .string(let stringInfo)? = itemInfo.properties?["id"]?.type else {
            Issue.record("Expected scores array of objects with id and score")
            return
        }
        #expect(stringInfo.choices == ["a", "b"])
    }

    @Test("Prompt lists each candidate as a JSON object with id and extras")
    func promptListsCandidatesAsJSON() throws {
        let eval = makeEvaluation(candidates: [
            candidate("a", extras: try AirshipJSON.wrap(["tier": "gold"])),
            candidate("b"),
        ])
        let prompt = eval.prompt(context: .empty)
        #expect(prompt.contains("\"id\" : \"a\""))
        #expect(prompt.contains("\"tier\" : \"gold\""))
        #expect(prompt.contains("\"id\" : \"b\""))
    }

    @Test("Extras cannot clobber the candidate's id")
    func promptKeepsInstanceIDWhenExtrasCarryAnID() throws {
        let eval = makeEvaluation(candidates: [
            candidate("a", extras: try AirshipJSON.wrap(["id": "author-supplied"])),
        ])
        let prompt = eval.prompt(context: .empty)
        // The instance ID is what scores are matched back by, so it has to survive.
        #expect(prompt.contains("\"id\" : \"a\""))
        // The author's value is still shown to the model, just not as the candidate id.
        #expect(prompt.contains("\"id\" : \"author-supplied\""))
    }

    @Test("User context items are appended to the prompt")
    func promptIncludesContext() {
        let eval = makeEvaluation(candidates: [candidate("a")])
        let context = AirshipAI.Context(items: [.init(content: "User is a dog owner")])
        let prompt = eval.prompt(context: context)
        #expect(prompt.contains("User is a dog owner"))
    }

    @Test("The layout's content_description rides on the candidate")
    func promptIncludesContentDescription() {
        let eval = makeEvaluation(candidates: [
            candidate("a", contentDescription: "Spring sale on cat trees"),
            candidate("b"),
        ])
        let prompt = eval.prompt(context: .empty)
        #expect(prompt.contains("\"description\" : \"Spring sale on cat trees\""))
    }

    @Test("additional_context never rides the candidate — it is pooled into the context")
    func promptKeepsCandidateBlockFreeOfContext() {
        let eval = makeEvaluation(candidates: [
            candidate(
                "a",
                additionalContext: [
                    .init(content: "Sale ends Friday", priority: -1),
                    .init(content: "Cat category"),
                ]
            )
        ])
        let prompt = eval.prompt(context: .empty)
        // The evaluation renders only what it is handed; pooling happens in `rank`, so an
        // empty context here must produce no context section at all.
        #expect(!prompt.contains("\"context\""))
        #expect(!prompt.contains("Sale ends Friday"))
        #expect(!prompt.contains("User context:"))
    }

    @Test("Pooled context renders in the one user-context section")
    func promptRendersPooledContextAsUserContext() {
        let eval = makeEvaluation(candidates: [candidate("a")])
        let prompt = eval.prompt(
            context: AirshipAI.Context(items: [
                .init(content: "User interests: cats"),
                .init(content: "Sale ends Friday", priority: -1),
            ])
        )
        // App-supplied and layout-supplied items are indistinguishable here by design.
        #expect(prompt.contains("User context:\n- User interests: cats\n- Sale ends Friday"))
    }

    @Test("A candidate with no content_description omits the key")
    func promptOmitsEmptyContentDescription() {
        let eval = makeEvaluation(candidates: [candidate("a")])
        let prompt = eval.prompt(context: .empty)
        #expect(!prompt.contains("\"description\""))
    }

    @Test("Author prompt appears in instructions")
    func instructionsUseAuthorPrompt() {
        let eval = makeEvaluation(
            prompt: "surface the most relevant promo",
            candidates: [candidate("a")]
        )
        #expect(eval.instructions().contains("surface the most relevant promo"))
    }
}

/// Backs the ranking path — the mock just returns a canned evaluation result to exercise
/// `rank`. Selection deliberately does NOT require app-registered user context (a prompt
/// plus `content_description` can rank on its own), so there is no context gate here; the
/// only pre-flight guard is that some candidate is describable.
private final class MockEmbeddedAIManager: AirshipAI.InternalManager, @unchecked Sendable {
    var evaluateResult: AirshipAI.Result<EmbeddedSelectionEvaluation.Output> = .skipped(reason: "test")
    private(set) var evaluateCallCount = 0
    private(set) var lastAdditionalContext: AirshipAI.Context = .empty

    var defaultModel: (any AirshipAI.ModelProtocol)? { nil }
    func model<S: Sendable>(for usage: AirshipAI.Usage<S>) -> (any AirshipAI.ModelProtocol)? { nil }
    func setContextProvider<S: Sendable>(for usage: AirshipAI.Usage<S>, _ provider: AirshipAI.ContextProvider<S>?) {}
    func setDefaultContextProvider(_ provider: (@Sendable () async -> AirshipAI.Context)?) {}
    func setEvaluationObserver(_ observer: AirshipAI.EvaluationObserver?) {}
    func setModelResolver(_ resolver: (@MainActor @Sendable (AirshipAI.AnyUsage) -> AirshipAI.ModelSelector)?) {}
    func registerModelFactory(_ factory: @MainActor @Sendable @escaping () -> any AirshipAI.ModelProtocol) {}
    func fetchContext<S: Sendable>(for usage: AirshipAI.Usage<S>, subject: S) async -> AirshipAI.Context { .empty }
    func gatedModel<S: Sendable>(for usage: AirshipAI.Usage<S>) -> (any AirshipAI.ModelProtocol)? { nil }
    func evaluate<E: AirshipAI.Evaluation>(_ evaluation: E, additionalContext: AirshipAI.Context) async -> AirshipAI.Result<E.Output> {
        evaluateCallCount += 1
        lastAdditionalContext = additionalContext
        return (evaluateResult as? AirshipAI.Result<E.Output>) ?? .skipped(reason: "test: unexpected type")
    }
}

struct DefaultEmbeddedAISelectorTest {

    /// Describable by default — a bare candidate is short-circuited before the model runs,
    /// which is its own test below rather than the precondition for every ranking test.
    private func candidate(_ id: String, priority: Int = 0) -> AirshipEmbeddedInfo {
        AirshipEmbeddedInfo(
            instanceID: id,
            embeddedID: "slot",
            extras: nil,
            priority: priority,
            contentDescription: "content \(id)"
        )
    }

    private func request(_ ids: [String]) -> EmbeddedAISelectionRequest {
        .init(embeddedID: "slot", prompt: "pick", candidates: ids.map { candidate($0) })
    }

    private func bareCandidate(_ id: String, priority: Int = 0) -> AirshipEmbeddedInfo {
        AirshipEmbeddedInfo(instanceID: id, embeddedID: "slot", extras: nil, priority: priority)
    }

    private func contextCandidate(_ id: String, context: [ThomasAIContextItem]) -> AirshipEmbeddedInfo {
        AirshipEmbeddedInfo(
            instanceID: id,
            embeddedID: "slot",
            extras: nil,
            priority: 0,
            contentDescription: "content \(id)",
            additionalContext: context
        )
    }

    @Test("Every candidate's additional_context is pooled into one context")
    func layoutContextIsPooled() async {
        let manager = MockEmbeddedAIManager()
        let selector = DefaultEmbeddedAISelector(aiManager: manager)

        _ = await selector.rank(
            .init(
                embeddedID: "slot",
                prompt: "pick",
                candidates: [
                    contextCandidate("a", context: [.init(content: "Owns two cats", priority: -1)]),
                    contextCandidate("b", context: [.init(content: "Targeted: lapsed buyer")]),
                ]
            )
        )

        #expect(
            manager.lastAdditionalContext.items == [
                .init(content: "Owns two cats", priority: -1),
                .init(content: "Targeted: lapsed buyer", priority: 0),
            ]
        )
    }

    @Test("A line repeated across sibling layouts is pooled once, at its best priority")
    func repeatedContextIsDeduped() async {
        let manager = MockEmbeddedAIManager()
        let selector = DefaultEmbeddedAISelector(aiManager: manager)

        _ = await selector.rank(
            .init(
                embeddedID: "slot",
                prompt: "pick",
                candidates: [
                    contextCandidate("a", context: [.init(content: "Sale ends Friday", priority: 3)]),
                    contextCandidate("b", context: [.init(content: "Sale ends Friday", priority: -1)]),
                ]
            )
        )

        // First-seen position, lowest (most important) priority — so a dedup can never make
        // an item more likely to be trimmed than the author asked for.
        #expect(manager.lastAdditionalContext.items == [.init(content: "Sale ends Friday", priority: -1)])
    }

    @Test("Candidates with no additional_context contribute no context")
    func noLayoutContextIsEmpty() async {
        let manager = MockEmbeddedAIManager()
        let selector = DefaultEmbeddedAISelector(aiManager: manager)

        _ = await selector.rank(request(["a", "b"]))

        #expect(manager.lastAdditionalContext.items.isEmpty)
    }

    @Test("Selection runs with no app context when candidates describe themselves")
    func runsWithoutAppContext() async {
        let manager = MockEmbeddedAIManager()
        let selector = DefaultEmbeddedAISelector(aiManager: manager)

        // The mock's context provider returns `.empty`; the model must still be asked.
        _ = await selector.rank(request(["a", "b"]))

        #expect(manager.evaluateCallCount == 1)
    }

    @Test("The model is skipped only when NO candidate is describable")
    func allIndistinguishableCandidatesSkipTheModel() async {
        let manager = MockEmbeddedAIManager()
        let selector = DefaultEmbeddedAISelector(aiManager: manager)

        let result = await selector.rank(
            .init(
                embeddedID: "slot",
                prompt: "pick",
                candidates: [bareCandidate("a"), bareCandidate("b")]
            )
        )

        // Bare UUIDs only — the model would score everything 5 and land on the fallback's
        // ordering anyway, so don't pay for the round-trip.
        #expect(result == nil)
        #expect(manager.evaluateCallCount == 0)
    }

    @Test("One describable candidate carries the whole set into the model")
    func oneDescribableCandidateRunsTheModel() async {
        let manager = MockEmbeddedAIManager()
        let selector = DefaultEmbeddedAISelector(aiManager: manager)

        // The guard is all-or-nothing: `a` is bare but still gets sent along with `b`.
        _ = await selector.rank(
            .init(
                embeddedID: "slot",
                prompt: "pick",
                candidates: [bareCandidate("a"), candidate("b")]
            )
        )

        #expect(manager.evaluateCallCount == 1)
    }

    @Test("Extras alone make a candidate describable")
    func extrasAloneAreDescribable() async throws {
        let manager = MockEmbeddedAIManager()
        let selector = DefaultEmbeddedAISelector(aiManager: manager)

        _ = await selector.rank(
            .init(
                embeddedID: "slot",
                prompt: "pick",
                candidates: [
                    AirshipEmbeddedInfo(
                        instanceID: "a",
                        embeddedID: "slot",
                        extras: try AirshipJSON.wrap(["tier": "gold"]),
                        priority: 0
                    )
                ]
            )
        )

        #expect(manager.evaluateCallCount == 1)
    }

    @Test("A candidate the model never scored falls to the end, not out of the ranking")
    func unscoredCandidatesRankLastRatherThanDrop() async {
        let manager = MockEmbeddedAIManager()
        manager.evaluateResult = .completed(
            .init(scores: [.init(id: "b", score: 9)], reason: "only b was scored")
        )
        let selector = DefaultEmbeddedAISelector(aiManager: manager)

        let result = await selector.rank(
            .init(
                embeddedID: "slot",
                prompt: "pick",
                candidates: [
                    bareCandidate("c", priority: 2),
                    candidate("b"),
                    bareCandidate("a", priority: 1),
                ]
            )
        )

        // Every candidate survives the ranking; the unscored ones trail, in priority order.
        #expect(result == ["b", "a", "c"])
    }

    @Test("A skipped evaluation falls back to the caller's ordering")
    func skippedResultFallsBack() async {
        let manager = MockEmbeddedAIManager()
        manager.evaluateResult = .skipped(reason: "no context")
        let selector = DefaultEmbeddedAISelector(aiManager: manager)

        let result = await selector.rank(request(["a", "b"]))

        #expect(result == nil)
    }

    @Test("A completed evaluation is ranked by score")
    func completedResultRanksByScore() async {
        let manager = MockEmbeddedAIManager()
        manager.evaluateResult = .completed(
            EmbeddedSelectionEvaluation.Output(
                scores: [.init(id: "a", score: 3), .init(id: "b", score: 9)],
                reason: "b matches"
            )
        )
        let selector = DefaultEmbeddedAISelector(aiManager: manager)

        let result = await selector.rank(request(["a", "b"]))

        #expect(manager.evaluateCallCount == 1)
        #expect(result == ["b", "a"])
    }
}
