/* Copyright Airship and Contributors */

import Foundation
import Testing

@testable import AirshipCore
@testable @_spi(AirshipInternal) import AirshipSceneRenderer

@Suite("Outcomes", .timeLimit(.minutes(1)))
struct ThomasActionPayloadOutcomeTest {

    @Test
    func actionsPayloadAsOutcomeWrapsPayload() throws {
        let json = try AirshipJSON.from(json: #"{"hello":"world"}"#)
        let payload = ThomasActionsPayload(value: json)
        guard case .airshipAction(let wrapped) = payload.asOutcome() else {
            Issue.record("Expected .airshipAction")
            return
        }
        #expect(wrapped.actions.value == payload.value)
        #expect(wrapped.identifier == "actions_payload")
    }

    @Test
    func actionsPayloadAsOutcomePreservesIosOverrides() throws {
        let json = try AirshipJSON.from(json: """
        {
          "display_landing_page": "https://example.com/a",
          "platform_action_overrides": {
            "ios": {
              "display_landing_page": "https://example.com/ios"
            }
          }
        }
        """)
        let payload = ThomasActionsPayload(value: json)
        guard case .airshipAction(let wrapped) = payload.asOutcome() else {
            Issue.record("Expected .airshipAction")
            return
        }
        let landing = try #require(wrapped.actions.value.object?["display_landing_page"])
        #expect(landing == .string("https://example.com/ios"))
        #expect(wrapped.identifier == "actions_payload")
    }

    @Test
    func actionsPayloadAsOutcomeWithIndexAppendsIndexToIdentifier() throws {
        let json = try AirshipJSON.from(json: #"{"k":"v"}"#)
        let payload = ThomasActionsPayload(value: json)
        guard case .airshipAction(let wrapped) = payload.asOutcome(index: 2) else {
            Issue.record("Expected .airshipAction")
            return
        }
        #expect(wrapped.identifier == "actions_payload_2")
    }

    @Test
    func clearStateAsOutcome() {
        let action = ThomasStateAction.clearState
        guard case .stateAction(let wrapped) = action.asOutcome else {
            Issue.record("Expected .stateAction")
            return
        }
        #expect(wrapped.action == .clearState)
        #expect(wrapped.identifier == "state_action_clear")
    }

    @Test
    func setStateAsOutcome() {
        let inner = ThomasStateAction.SetState(key: "k", value: .string("v"), ttl: 99)
        let action = ThomasStateAction.setState(inner)
        guard case .stateAction(let wrapped) = action.asOutcome else {
            Issue.record("Expected .stateAction")
            return
        }
        #expect(wrapped.action == action)
        #expect(wrapped.identifier == "state_action_set_k")
    }

    @Test
    func formValueAsOutcome() {
        let inner = ThomasStateAction.SetFormValue(key: "field_key")
        let action = ThomasStateAction.formValue(inner)
        guard case .stateAction(let wrapped) = action.asOutcome else {
            Issue.record("Expected .stateAction")
            return
        }
        #expect(wrapped.action == action)
        #expect(wrapped.identifier == "state_action_set_set_form_value_field_key")
    }
}
