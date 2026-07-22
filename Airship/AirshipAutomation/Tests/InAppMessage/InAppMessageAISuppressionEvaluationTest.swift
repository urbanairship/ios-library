/* Copyright Airship and Contributors */

import Testing
import Foundation
@_spi(AirshipInternal) import AirshipBasement
@_spi(AirshipInternal) @testable import AirshipAutomation
@_spi(AirshipInternal) import AirshipCore

struct InAppMessageAISuppressionEvaluationTest {

    // MARK: - instructions()

    @Test
    func instructionsUseConditionAsCondition() {
        let eval = InAppMessageAISuppressionEvaluation(
            condition: "Only show to frequent flyers",
            subject: .init(name: "Test")
        )
        let instructions = eval.instructions()
        #expect(instructions.contains("Only show to frequent flyers"))
        #expect(instructions.contains("Show the message only when"))
    }

    @Test
    func instructionsFallBackWhenConditionEmpty() {
        let eval = InAppMessageAISuppressionEvaluation(condition: "", subject: .init(name: "Test"))
        #expect(eval.instructions().contains("When in doubt, show it"))
    }

    // MARK: - prompt()

    @Test
    func promptIncludesMessageName() {
        let eval = InAppMessageAISuppressionEvaluation(condition: "", subject: .init(name: "Summer Promo"))
        #expect(eval.prompt().contains("Message name: Summer Promo"))
    }

    @Test
    func conditionLivesInInstructionsNotPrompt() {
        let eval = InAppMessageAISuppressionEvaluation(
            condition: "Only show to frequent flyers",
            subject: .init(name: "Test")
        )
        #expect(eval.instructions().contains("Only show to frequent flyers"))
        #expect(!eval.prompt().contains("Only show to frequent flyers"))
    }

    @Test
    func promptIncludesExtrasAsJSON() {
        let eval = InAppMessageAISuppressionEvaluation(
            condition: "",
            subject: .init(name: "Test", extras: ["promo_type": "flash_sale"])
        )
        let prompt = eval.prompt()
        #expect(prompt.contains("Message Extras:"))
        #expect(prompt.contains("promo_type"))
        #expect(prompt.contains("flash_sale"))
    }

    @Test
    func promptOmitsExtrasWhenNil() {
        let eval = InAppMessageAISuppressionEvaluation(condition: "", subject: .init(name: "Test"))
        #expect(!eval.prompt().contains("Message Extras:"))
    }

    @Test
    func promptIncludesPriority() {
        let eval = InAppMessageAISuppressionEvaluation(
            condition: "",
            subject: .init(name: "Test", priority: 3)
        )
        #expect(eval.prompt().contains("Message priority: 3"))
    }

    @Test
    func hintsAreNeverRenderedIntoPrompt() {
        let eval = InAppMessageAISuppressionEvaluation(
            condition: "",
            subject: .init(name: "Test", hints: ["secret": "value"])
        )
        #expect(!eval.prompt().contains("secret"))
        #expect(!eval.prompt().contains("value"))
    }

    @Test
    func promptContainsOnlySubjectContent() {
        // Provider context is appended by the model, never by the evaluation.
        let eval = InAppMessageAISuppressionEvaluation(condition: "", subject: .init(name: "Test", priority: 0))
        #expect(eval.prompt() == "Message name: Test\nMessage priority: 0")
    }
}
