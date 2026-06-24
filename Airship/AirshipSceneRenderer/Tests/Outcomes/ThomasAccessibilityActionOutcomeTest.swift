/* Copyright Airship and Contributors */

import Foundation
import Testing

@testable import AirshipCore
@testable import AirshipSceneRenderer

@Suite("Outcomes", .timeLimit(.minutes(1)))
struct ThomasAccessibilityActionOutcomeTest {

    private let decoder = JSONDecoder()

    @Test
    func preparedOutcomesReturnsOutcomesWhenPresent() throws {
        let json = """
        {
          "type": "default",
          "behaviors": ["cancel"],
          "outcomes": [
            { "type": "dismiss", "cancel": true, "identifier": "a11y.dismiss.true" }
          ]
        }
        """
        let action = try decoder.decode(ThomasAccessibilityAction.self, from: Data(json.utf8))
        let expected = try #require(action.properties.outcomes)
        #expect(action.preparedOutcomes() == expected)
    }

    @Test
    func preparedOutcomesMapsBehaviorsAndActionsWhenOutcomesNil() throws {
        let json = """
        {
          "type": "default",
          "behaviors": ["video_play"],
          "actions": [
            { "add_tags": ["x"] }
          ]
        }
        """
        let action = try decoder.decode(ThomasAccessibilityAction.self, from: Data(json.utf8))
        let result = action.preparedOutcomes()
        #expect(result.count == 2)
        #expect(result[0] == ThomasButtonClickBehavior.videoPlay.asOutcome)
        guard case .airshipAction(let wrapped) = result[1] else {
            Issue.record("Expected wrapped actions")
            return
        }
        #expect(wrapped.identifier == "actions_payload_0")
    }

    @Test
    func preparedOutcomesLegacyIdentifiersFollowBehaviorThenIndexedActions() throws {
        let json = """
        {
          "type": "default",
          "behaviors": ["video_play", "pager_next"],
          "actions": [
            { "a": 1 },
            { "b": 2 }
          ]
        }
        """
        let action = try decoder.decode(ThomasAccessibilityAction.self, from: Data(json.utf8))
        let result = action.preparedOutcomes()
        #expect(result.count == 4)
        guard case .mediaPlayback(let media) = result[0] else {
            Issue.record("Expected media playback from first behavior")
            return
        }
        #expect(media.identifier == ThomasButtonClickBehavior.videoPlay.outcomeIdentifier)
        guard case .pagerStepNavigation(let nav) = result[1] else {
            Issue.record("Expected pager step from second behavior")
            return
        }
        #expect(nav.identifier == ThomasButtonClickBehavior.pagerNext.outcomeIdentifier)
        guard case .airshipAction(let air0) = result[2] else {
            Issue.record("Expected first actions outcome")
            return
        }
        #expect(air0.identifier == "actions_payload_0")
        guard case .airshipAction(let air1) = result[3] else {
            Issue.record("Expected second actions outcome")
            return
        }
        #expect(air1.identifier == "actions_payload_1")
    }

    @Test
    func preparedOutcomesEmptyWhenAllNil() throws {
        let json = """
        {
          "type": "escape"
        }
        """
        let action = try decoder.decode(ThomasAccessibilityAction.self, from: Data(json.utf8))
        #expect(action.preparedOutcomes().isEmpty)
    }

    @Test
    func decodeWithOutcomesField() throws {
        let json = """
        {
          "type": "escape",
          "outcomes": [
            { "type": "dismiss", "cancel": false, "identifier": "a11y.dismiss.false" }
          ]
        }
        """
        let decoded = try decoder.decode(ThomasAccessibilityAction.self, from: Data(json.utf8))
        #expect(decoded.properties.outcomes?.count == 1)
    }

    @Test
    func decodeWithoutOutcomesBackwardCompat() throws {
        let json = """
        {
          "type": "default",
          "behaviors": ["pager_next"]
        }
        """
        let decoded = try decoder.decode(ThomasAccessibilityAction.self, from: Data(json.utf8))
        #expect(decoded.properties.outcomes == nil)
        #expect(decoded.properties.behaviors == [.pagerNext])
    }
}
