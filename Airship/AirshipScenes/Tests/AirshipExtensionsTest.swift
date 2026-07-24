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
        let contextRange = combined.range(of: "Background context:")!
        #expect(inputRange.lowerBound < contextRange.lowerBound)
        #expect(combined.contains("- Name: Alice"))
    }

    @Test("The tag is regenerated per evaluation so it can't be guessed/injected")
    func tagRegeneratesPerEvaluation() {
        #expect(makeEvaluation(text: "x").inputTag != makeEvaluation(text: "x").inputTag)
    }
}
