/* Copyright Airship and Contributors */

import Foundation
import Testing

@testable import AirshipCore
@testable import AirshipSceneRenderer

@Suite("Outcomes", .timeLimit(.minutes(1)))
struct ThomasAutomatedActionOutcomeTest {

    private let decoder = JSONDecoder()

    @Test
    func preparedOutcomesReturnsOutcomesWhenPresent() throws {
        let list: [ThomasOutcome] = [.dismiss(.init(cancel: false, identifier: "auto.explicit.dismiss"))]
        let emptyPayload = ThomasActionsPayload(value: try AirshipJSON.from(json: "{}"))
        let action = ThomasAutomatedAction(
            identifier: "a1",
            delay: nil,
            actions: [emptyPayload],
            behaviors: [.dismiss],
            reportingMetadata: nil,
            outcomes: list
        )
        #expect(action.preparedOutcomes() == list)
    }

    @Test
    func preparedOutcomesMapsBehaviorsAndActionsWhenOutcomesNil() throws {
        let payload = ThomasActionsPayload(value: try AirshipJSON.from(json: #"{"x":1}"#))
        let action = ThomasAutomatedAction(
            identifier: "a1",
            delay: nil,
            actions: [payload],
            behaviors: [.pagerNext, .pagerPrevious],
            reportingMetadata: nil,
            outcomes: nil
        )
        let result = action.preparedOutcomes()
        #expect(result.count == 3)
        #expect(result[0] == ThomasButtonClickBehavior.pagerNext.asOutcome)
        #expect(result[1] == ThomasButtonClickBehavior.pagerPrevious.asOutcome)
        #expect(result[2] == payload.asOutcome(index: 0))
    }

    @Test
    func preparedOutcomesLegacyUsesBehaviorOutcomeIdentifiersAndIndexedActionPayloadIds() throws {
        let p0 = ThomasActionsPayload(value: try AirshipJSON.from(json: #"{"i":0}"#))
        let p1 = ThomasActionsPayload(value: try AirshipJSON.from(json: #"{"i":1}"#))
        let action = ThomasAutomatedAction(
            identifier: "a1",
            delay: nil,
            actions: [p0, p1],
            behaviors: [.pagerNext, .formSubmit],
            reportingMetadata: nil,
            outcomes: nil
        )
        let result = action.preparedOutcomes()
        #expect(result.count == 4)
        guard case .pagerStepNavigation(let nav) = result[0] else {
            Issue.record("Expected pager step from behavior")
            return
        }
        #expect(nav.identifier == ThomasButtonClickBehavior.pagerNext.outcomeIdentifier)
        guard case .form(let form) = result[1] else {
            Issue.record("Expected form from behavior")
            return
        }
        #expect(form.identifier == ThomasButtonClickBehavior.formSubmit.outcomeIdentifier)
        guard case .airshipAction(let air0) = result[2] else {
            Issue.record("Expected first action outcome")
            return
        }
        #expect(air0.identifier == "actions_payload_0")
        guard case .airshipAction(let air1) = result[3] else {
            Issue.record("Expected second action outcome")
            return
        }
        #expect(air1.identifier == "actions_payload_1")
    }

    @Test
    func preparedOutcomesEmptyWhenAllNil() {
        let action = ThomasAutomatedAction(
            identifier: "a1",
            delay: nil,
            actions: nil,
            behaviors: nil,
            reportingMetadata: nil,
            outcomes: nil
        )
        #expect(action.preparedOutcomes().isEmpty)
    }

    @Test
    func preparedOutcomesOrderBehaviorsBeforeActions() throws {
        let payload = ThomasActionsPayload(value: try AirshipJSON.from(json: "{}"))
        let action = ThomasAutomatedAction(
            identifier: "a1",
            delay: nil,
            actions: [payload],
            behaviors: [.formSubmit],
            reportingMetadata: nil,
            outcomes: nil
        )
        let result = action.preparedOutcomes()
        #expect(result.count == 2)
        guard case .form(let first) = result[0] else {
            Issue.record("Expected form outcome first")
            return
        }
        #expect(first.command == .submit)
        guard case .airshipAction = result[1] else {
            Issue.record("Expected action outcome second")
            return
        }
    }

    @Test
    func decodeWithOutcomesField() throws {
        let json = """
        {
          "identifier": "auto1",
          "outcomes": [
            { "type": "dismiss", "cancel": false, "identifier": "auto.json.dismiss" }
          ]
        }
        """
        let decoded = try decoder.decode(ThomasAutomatedAction.self, from: Data(json.utf8))
        #expect(decoded.outcomes?.count == 1)
    }

    @Test
    func decodeWithoutOutcomesBackwardCompat() throws {
        let json = """
        {
          "identifier": "auto1",
          "behaviors": ["pager_next"]
        }
        """
        let decoded = try decoder.decode(ThomasAutomatedAction.self, from: Data(json.utf8))
        #expect(decoded.outcomes == nil)
        #expect(decoded.behaviors == [.pagerNext])
    }
}
