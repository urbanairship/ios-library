/* Copyright Airship and Contributors */

import Testing
import Foundation

@_spi(AirshipInternal) import AirshipBasement
@testable @_spi(AirshipInternal) import AirshipSceneRenderer

@MainActor
struct ThomasPropertyOverrideTest {

    private func overrides(_ json: String) throws -> [ThomasPropertyOverride<String>] {
        try JSONDecoder().decode([ThomasPropertyOverride<String>].self, from: Data(json.utf8))
    }

    private let state = ThomasState(
        mutableState: ThomasState.MutableState(initialState: ["flag": true]),
        onStateChange: { _ in }
    )

    @Test("a matched override with no value keeps the default")
    func valuelessMatchKeepsDefault() throws {
        let valueless = try overrides(#"[{"when_state_matches": {"key": "flag", "value": {"equals": true}}}]"#)
        #expect(ThomasPropertyOverride.resolveOptional(state: state, overrides: valueless, defaultValue: "default") == "default")
        #expect(ThomasPropertyOverride.resolveOptional(state: state, overrides: valueless) == nil)
    }

    @Test("the first matching override wins, and one with no predicate always matches")
    func firstMatchWins() throws {
        let list = try overrides(#"""
        [
          {"when_state_matches": {"key": "flag", "value": {"equals": false}}, "value": "unmatched"},
          {"value": "unconditional"},
          {"when_state_matches": {"key": "flag", "value": {"equals": true}}, "value": "later"}
        ]
        """#)
        #expect(ThomasPropertyOverride.resolveOptional(state: state, overrides: list, defaultValue: "default") == "unconditional")
        #expect(ThomasPropertyOverride.resolveOptional(state: state, overrides: [], defaultValue: "default") == "default")
    }
}
