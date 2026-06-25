/* Copyright Airship and Contributors */

import Foundation
import Testing

@testable import AirshipCore
@testable @_spi(AirshipInternal) import AirshipSceneRenderer

@Suite(.timeLimit(.minutes(1)))
struct ThomasStateTriggerTest {

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private let predicateFragment = """
    "trigger_when_state_matches": {
      "scope": ["flag"],
      "value": { "equals": [true] }
    }
    """

    @Test
    func decodeTriggerActionsStateActionsOnly() throws {
        let json = """
        {
          "identifier": "t1",
          \(predicateFragment),
          "on_trigger": {
            "state_actions": [
              { "type": "clear" }
            ]
          }
        }
        """
        let trigger = try decoder.decode(ThomasStateTriggers.self, from: Data(json.utf8))
        #expect(trigger.onTrigger.stateActions?.count == 1)
        #expect(trigger.onTrigger.outcomes == nil)
    }

    @Test
    func decodeTriggerActionsOutcomesOnly() throws {
        let json = """
        {
          "identifier": "t1",
          \(predicateFragment),
          "on_trigger": {
            "outcomes": [
              { "type": "dismiss", "cancel": false, "identifier": "trigger.dismiss" }
            ]
          }
        }
        """
        let trigger = try decoder.decode(ThomasStateTriggers.self, from: Data(json.utf8))
        #expect(trigger.onTrigger.outcomes?.count == 1)
        #expect(trigger.onTrigger.stateActions == nil)
    }

    @Test
    func decodeTriggerActionsBothFieldsPresent() throws {
        let json = """
        {
          "identifier": "t1",
          \(predicateFragment),
          "on_trigger": {
            "outcomes": [
              { "type": "dismiss", "cancel": true, "identifier": "trigger.dismiss.true" }
            ],
            "state_actions": [
              { "type": "clear" }
            ]
          }
        }
        """
        let trigger = try decoder.decode(ThomasStateTriggers.self, from: Data(json.utf8))
        #expect(trigger.onTrigger.outcomes != nil)
        #expect(trigger.onTrigger.stateActions != nil)
    }

    @Test
    func roundTripTriggerActionsWithOutcomes() throws {
        let original = ThomasStateTriggers(
            id: "tid",
            triggerWhenStateMatches: JSONPredicate(jsonMatcher: JSONMatcher(
                valueMatcher: .matcherWhereBooleanEquals(true),
                scope: ["s"]
            )),
            resetWhenStateMatches: nil,
            onTrigger: .init(
                stateActions: nil,
                outcomes: [.dismiss(.init(cancel: false, identifier: "trigger.rt.dismiss"))]
            )
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ThomasStateTriggers.self, from: data)
        #expect(decoded.onTrigger.outcomes?.count == 1)
    }

    @Test
    func roundTripTriggerActionsWithoutOutcomes() throws {
        let original = ThomasStateTriggers(
            id: "tid",
            triggerWhenStateMatches: JSONPredicate(jsonMatcher: JSONMatcher(
                valueMatcher: .matcherWhereBooleanEquals(false),
                scope: ["s"]
            )),
            resetWhenStateMatches: nil,
            onTrigger: .init(
                stateActions: [.clearState],
                outcomes: nil
            )
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ThomasStateTriggers.self, from: data)
        #expect(decoded.onTrigger.stateActions?.count == 1)
        #expect(decoded.onTrigger.outcomes == nil)
    }
}
