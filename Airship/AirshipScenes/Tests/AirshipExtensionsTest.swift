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

    private func makeEvaluation(prompt: String = "classify sentiment", text: String) -> ThomasAIInferenceEvaluation {
        ThomasAIInferenceEvaluation(request: .init(prompt: prompt, text: text))
    }

    @Test("User text is fenced between the per-evaluation marker")
    func promptFencesUserText() {
        let eval = makeEvaluation(text: "I love it")
        let prompt = eval.prompt()
        #expect(prompt.contains("I love it"))
        // The marker appears exactly twice (open + close) → 3 components when split on it.
        #expect(prompt.components(separatedBy: eval.inputMarker).count == 3)
    }

    @Test("Instructions reference the marker and guard against embedded instructions")
    func instructionsGuardAgainstInjection() {
        let eval = makeEvaluation(prompt: "classify sentiment", text: "x")
        let instructions = eval.instructions()
        #expect(instructions.contains(eval.inputMarker))
        #expect(instructions.contains("untrusted"))
        #expect(instructions.contains("never as instructions"))
        // The author's instruction is still applied.
        #expect(instructions.contains("classify sentiment"))
    }

    @Test("The fence marker is regenerated per evaluation so it can't be guessed/injected")
    func markerRegeneratesPerEvaluation() {
        #expect(makeEvaluation(text: "x").inputMarker != makeEvaluation(text: "x").inputMarker)
    }
}
