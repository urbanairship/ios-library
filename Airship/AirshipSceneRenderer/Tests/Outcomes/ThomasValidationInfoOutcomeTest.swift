/* Copyright Airship and Contributors */

import Foundation
import Testing

@testable import AirshipCore
@testable import AirshipSceneRenderer

@Suite("Outcomes", .timeLimit(.minutes(1)))
struct ThomasValidationInfoOutcomeTest {

    private let decoder = JSONDecoder()
    private let dismissOutcome = ThomasOutcome.dismiss(.init(cancel: false, identifier: "validation.dismiss"))

    // MARK: - EditInfo

    @Test
    func editInfoOutcomesWinOverStateActions() {
        let info = ThomasValidationInfo.EditInfo(
            stateActions: [.clearState],
            outcomes: [dismissOutcome]
        )
        #expect(info.getOutcomes() == [dismissOutcome])
    }

    @Test
    func editInfoFallsBackToStateActions() {
        let info = ThomasValidationInfo.EditInfo(
            stateActions: [.clearState],
            outcomes: nil
        )
        #expect(info.getOutcomes() == [ThomasStateAction.clearState.asOutcome])
    }

    @Test
    func editInfoNilWhenBothMissing() {
        let info = ThomasValidationInfo.EditInfo(stateActions: nil, outcomes: nil)
        #expect(info.getOutcomes() == nil)
    }

    // MARK: - ErrorInfo

    @Test
    func errorInfoOutcomesWinOverStateActions() {
        let info = ThomasValidationInfo.ErrorInfo(
            stateActions: [.clearState],
            outcomes: [dismissOutcome]
        )
        #expect(info.getOutcomes() == [dismissOutcome])
    }

    @Test
    func errorInfoFallsBackToStateActions() {
        let info = ThomasValidationInfo.ErrorInfo(
            stateActions: [.clearState],
            outcomes: nil
        )
        #expect(info.getOutcomes() == [ThomasStateAction.clearState.asOutcome])
    }

    @Test
    func errorInfoNilWhenBothMissing() {
        let info = ThomasValidationInfo.ErrorInfo(stateActions: nil, outcomes: nil)
        #expect(info.getOutcomes() == nil)
    }

    // MARK: - ValidInfo

    @Test
    func validInfoOutcomesWinOverStateActions() {
        let info = ThomasValidationInfo.ValidInfo(
            stateActions: [.clearState],
            outcomes: [dismissOutcome]
        )
        #expect(info.getOutcomes() == [dismissOutcome])
    }

    @Test
    func validInfoFallsBackToStateActions() {
        let info = ThomasValidationInfo.ValidInfo(
            stateActions: [.clearState],
            outcomes: nil
        )
        #expect(info.getOutcomes() == [ThomasStateAction.clearState.asOutcome])
    }

    @Test
    func validInfoNilWhenBothMissing() {
        let info = ThomasValidationInfo.ValidInfo(stateActions: nil, outcomes: nil)
        #expect(info.getOutcomes() == nil)
    }

    // MARK: - JSON

    @Test
    func decodeOutcomesFieldOnEdit() throws {
        let json = """
        {
          "on_edit": {
            "outcomes": [
              { "type": "dismiss", "cancel": false, "identifier": "validation.json.dismiss" }
            ]
          }
        }
        """
        let info = try decoder.decode(ThomasValidationInfo.self, from: Data(json.utf8))
        let edit = try #require(info.onEdit)
        #expect(edit.outcomes?.count == 1)
        #expect(edit.getOutcomes()?.count == 1)
    }

    @Test
    func decodeStateActionsOnlyBackwardCompat() throws {
        let json = """
        {
          "on_edit": {
            "state_actions": [
              { "type": "clear" }
            ]
          }
        }
        """
        let info = try decoder.decode(ThomasValidationInfo.self, from: Data(json.utf8))
        let edit = try #require(info.onEdit)
        #expect(edit.outcomes == nil)
        #expect(edit.stateActions?.count == 1)
        #expect(edit.getOutcomes()?.count == 1)
    }

    @Test
    func decodeBothFieldsOutcomesTakePriority() throws {
        let json = """
        {
          "on_valid": {
            "outcomes": [
              { "type": "dismiss", "cancel": true, "identifier": "validation.json.dismiss.true" }
            ],
            "state_actions": [
              { "type": "clear" }
            ]
          }
        }
        """
        let info = try decoder.decode(ThomasValidationInfo.self, from: Data(json.utf8))
        let valid = try #require(info.onValid)
        #expect(valid.outcomes != nil)
        #expect(valid.stateActions != nil)
        guard case .dismiss(let d) = valid.getOutcomes()?.first else {
            Issue.record("Expected dismiss outcome")
            return
        }
        #expect(d.cancel == true)
    }
}
