/* Copyright Airship and Contributors */

import Foundation
import Testing

@testable import AirshipCore
@testable import AirshipSceneRenderer

@Suite(.timeLimit(.minutes(1)))
struct ThomasEventHandlerTest {

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    @Test
    func decodeStateActionsOnlyBackwardCompat() throws {
        let json = """
        {
          "type": "tap",
          "state_actions": [
            { "type": "clear" }
          ]
        }
        """
        let handler = try decoder.decode(ThomasEventHandler.self, from: Data(json.utf8))
        #expect(handler.type == .tap)
        #expect(handler.stateActions.count == 1)
        #expect(handler.outcomes == nil)
    }

    @Test
    func decodeBothFieldsPresent() throws {
        let json = """
        {
          "type": "tap",
          "outcomes": [
            { "type": "dismiss", "cancel": true, "identifier": "handler.dismiss" }
          ],
          "state_actions": [
            { "type": "clear" }
          ]
        }
        """
        let handler = try decoder.decode(ThomasEventHandler.self, from: Data(json.utf8))
        #expect(handler.outcomes != nil)
        #expect(handler.stateActions.count == 1)
    }

    @Test
    func roundTripWithOutcomes() throws {
        let original = ThomasEventHandler(
            type: .formInput,
            stateActions: [],
            outcomes: [.pagerPlayback(.init(command: .pause, identifier: "handler.pb"))]
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ThomasEventHandler.self, from: data)
        #expect(decoded == original)
    }

    @Test
    func roundTripWithoutOutcomes() throws {
        let original = ThomasEventHandler(
            type: .tap,
            stateActions: [.clearState],
            outcomes: nil
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ThomasEventHandler.self, from: data)
        #expect(decoded == original)
    }
}
