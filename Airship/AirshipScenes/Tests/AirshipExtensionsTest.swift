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

    private func candidate(_ id: String, extras: AirshipJSON? = nil, priority: Int = 0) -> AirshipEmbeddedInfo {
        AirshipEmbeddedInfo(instanceID: id, embeddedID: "slot", extras: extras, priority: priority)
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

    @Test("User context items are appended to the prompt")
    func promptIncludesContext() {
        let eval = makeEvaluation(candidates: [candidate("a")])
        let context = AirshipAI.Context(items: [.init(content: "User is a dog owner")])
        let prompt = eval.prompt(context: context)
        #expect(prompt.contains("User is a dog owner"))
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
