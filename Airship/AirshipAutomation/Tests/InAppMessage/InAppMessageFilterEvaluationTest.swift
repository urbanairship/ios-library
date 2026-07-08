/* Copyright Airship and Contributors */

import Testing
import Foundation
@_spi(AirshipInternal) import AirshipBasement
@_spi(AirshipInternal) @testable import AirshipAutomation
@_spi(AirshipInternal) import AirshipCore

struct InAppMessageFilterEvaluationTest {

    // MARK: - instructions()

    @Test
    func instructionsContainBaseDirective() {
        let eval = InAppMessageFilterEvaluation(filterPrompt: "", subject: .init(name: "Test"))
        #expect(eval.instructions().contains("relevant to the current user"))
    }

    // MARK: - prompt(context:)

    @Test
    func promptIncludesMessageName() {
        let eval = InAppMessageFilterEvaluation(filterPrompt: "", subject: .init(name: "Summer Promo"))
        #expect(eval.prompt(context: .empty).contains("Message name: Summer Promo"))
    }

    @Test
    func promptIncludesFilterInstruction() {
        let eval = InAppMessageFilterEvaluation(
            filterPrompt: "Only show to frequent flyers",
            subject: .init(name: "Test")
        )
        #expect(eval.prompt(context: .empty).contains("Filter instruction: Only show to frequent flyers"))
    }

    @Test
    func promptOmitsFilterInstructionWhenEmpty() {
        let eval = InAppMessageFilterEvaluation(filterPrompt: "", subject: .init(name: "Test"))
        #expect(!eval.prompt(context: .empty).contains("Filter instruction:"))
    }

    @Test
    func promptIncludesExtrasAsJSON() {
        let eval = InAppMessageFilterEvaluation(
            filterPrompt: "",
            subject: .init(name: "Test", extras: ["promo_type": "flash_sale"])
        )
        let prompt = eval.prompt(context: .empty)
        #expect(prompt.contains("Message Extras:"))
        #expect(prompt.contains("promo_type"))
        #expect(prompt.contains("flash_sale"))
    }

    @Test
    func promptOmitsExtrasWhenNil() {
        let eval = InAppMessageFilterEvaluation(filterPrompt: "", subject: .init(name: "Test"))
        #expect(!eval.prompt(context: .empty).contains("Message Extras:"))
    }

    @Test
    func promptIncludesCampaignsAsJSON() {
        let eval = InAppMessageFilterEvaluation(
            filterPrompt: "",
            subject: .init(name: "Test", campaigns: ["campaign_name": "summer_promo"])
        )
        let prompt = eval.prompt(context: .empty)
        #expect(prompt.contains("Campaigns:"))
        #expect(prompt.contains("campaign_name"))
        #expect(prompt.contains("summer_promo"))
    }

    @Test
    func promptOmitsCampaignsSectionWhenNil() {
        let eval = InAppMessageFilterEvaluation(filterPrompt: "", subject: .init(name: "Test"))
        #expect(!eval.prompt(context: .empty).contains("Campaigns:"))
    }

    @Test
    func promptIncludesContextSummary() {
        let eval = InAppMessageFilterEvaluation(filterPrompt: "", subject: .init(name: "Test"))
        let context = AirshipAI.Context(summary: "power user, travels often")
        #expect(eval.prompt(context: context).contains("User context: power user, travels often"))
    }

    @Test
    func promptIncludesContextAttributes() {
        let eval = InAppMessageFilterEvaluation(filterPrompt: "", subject: .init(name: "Test"))
        let context = AirshipAI.Context(attributes: ["named_user": .string("ryan")])
        let prompt = eval.prompt(context: context)
        #expect(prompt.contains("User attributes:"))
        #expect(prompt.contains("named_user"))
        #expect(prompt.contains("ryan"))
    }

    @Test
    func promptOmitsAttributesSectionWhenEmpty() {
        let eval = InAppMessageFilterEvaluation(filterPrompt: "", subject: .init(name: "Test"))
        #expect(!eval.prompt(context: .empty).contains("User attributes:"))
    }
}
