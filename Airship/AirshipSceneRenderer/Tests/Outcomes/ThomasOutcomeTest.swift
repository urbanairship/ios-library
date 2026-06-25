/* Copyright Airship and Contributors */

import Foundation
import Testing

@testable import AirshipCore
@testable @_spi(AirshipInternal) import AirshipSceneRenderer

@Suite("Outcomes", .timeLimit(.minutes(1)))
struct ThomasOutcomeTest {

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    /// Stable identifier used in JSON decode/round-trip fixtures.
    private static let oid = "fixture_oid"

    // MARK: - AirshipAction

    @Test
    func decodeAirshipActionOutcome() async throws {
        let json = """
        {
            "type": "airship_action",
            "identifier": "\(Self.oid)",
            "actions": { "display_landing_page": "https://example.com" }
        }
        """
        let outcome = try decode(json)
        guard case .airshipAction(let payload) = outcome else {
            Issue.record("Expected .airshipAction, got \(outcome)")
            return
        }
        #expect(payload.type == .airshipAction)
        #expect(payload.identifier == Self.oid)
    }

    @Test
    func roundTripAirshipActionOutcome() async throws {
        try assertRoundTrip("""
        {
            "type": "airship_action",
            "identifier": "\(Self.oid)",
            "actions": { "add_tags": ["tag1", "tag2"] }
        }
        """)
    }

    // MARK: - Dismiss

    @Test
    func decodeDismissOutcomeWithoutCancel() async throws {
        let outcome = try decode("{\"type\": \"dismiss\", \"identifier\": \"\(Self.oid)\"}")
        guard case .dismiss(let payload) = outcome else {
            Issue.record("Expected .dismiss, got \(outcome)")
            return
        }
        #expect(payload.cancel == nil)
        #expect(payload.identifier == Self.oid)
    }

    @Test
    func decodeDismissOutcomeWithCancelTrue() async throws {
        let outcome = try decode("""
            {"type": "dismiss", "cancel": true, "identifier": "\(Self.oid)"}
        """)
        guard case .dismiss(let payload) = outcome else {
            Issue.record("Expected .dismiss, got \(outcome)")
            return
        }
        #expect(payload.cancel == true)
        #expect(payload.identifier == Self.oid)
    }

    @Test
    func decodeDismissOutcomeWithCancelFalse() async throws {
        let outcome = try decode("""
            {"type": "dismiss", "cancel": false, "identifier": "\(Self.oid)"}
        """)
        
        guard case .dismiss(let payload) = outcome else {
            Issue.record("Expected .dismiss, got \(outcome)")
            return
        }
        #expect(payload.cancel == false)
    }

    @Test
    func roundTripDismissOutcome() async throws {
        try assertRoundTrip("""
            {"type": "dismiss", "identifier": "\(Self.oid)"}
        """)
        
        try assertRoundTrip("""
            {"type": "dismiss", "cancel": true, "identifier": "\(Self.oid)"}
        """)
    }

    // MARK: - PagerPlayback

    @Test("Decode pager_playback – all commands", arguments: ["pause", "resume", "toggle"])
    func decodePagerPlaybackOutcome(command: String) async throws {
        let outcome = try decode("""
            {"type": "pager_playback", "command": "\(command)", "identifier": "\(Self.oid)"}
        """)
        
        guard case .pagerPlayback(let payload) = outcome else {
            Issue.record("Expected .pagerPlayback, got \(outcome)")
            return
        }
        #expect(payload.command.rawValue == command)
    }

    @Test
    func roundTripPagerPlaybackOutcome() async throws {
        try assertRoundTrip("""
            {"type": "pager_playback", "command": "toggle", "identifier": "\(Self.oid)"}
        """)
    }

    // MARK: - PagerJumpNavigation
    @Test("Decode pager_jump_navigation – all pages", arguments: ["start", "end"])
    func decodePagerJumpNavigationOutcome(page: String) async throws {
        let outcome = try decode("""
            {"type": "pager_jump_navigation", "page": "\(page)", "identifier": "\(Self.oid)"}
        """)
        
        guard case .pagerJumpNavigation(let payload) = outcome else {
            Issue.record("Expected .pagerJumpNavigation, got \(outcome)")
            return
        }
        
        #expect(payload.page.rawValue == page)
    }

    @Test
    func roundTripPagerJumpNavigationOutcome() async throws {
        try assertRoundTrip("""
            {"type": "pager_jump_navigation", "page": "end", "identifier": "\(Self.oid)"}
        """)
    }

    // MARK: - PagerStepNavigation
    @Test
    func decodePagerStepNavigationDefaultsBoundaryBehaviorToIgnore() async throws {
        let outcome = try decode("""
            {"type": "pager_step_navigation", "direction": "next", "identifier": "\(Self.oid)"}
        """)
        guard case .pagerStepNavigation(let payload) = outcome else {
            Issue.record("Expected .pagerStepNavigation, got \(outcome)")
            return
        }
        
        #expect(payload.direction == .next)
        #expect(payload.boundaryBehavior == .ignore)
    }

    @Test("Decode pager_step_navigation – all boundary behaviors", arguments: ["wrap", "dismiss", "ignore"])
    func decodePagerStepNavigationBoundaryBehaviors(behavior: String) async throws {
        let json = """
        {
            "type": "pager_step_navigation",
            "direction": "previous",
            "boundary_behavior": "\(behavior)",
            "identifier": "\(Self.oid)"
        }
        """
        let outcome = try decode(json)
        guard case .pagerStepNavigation(let payload) = outcome else {
            Issue.record("Expected .pagerStepNavigation, got \(outcome)")
            return
        }
        #expect(payload.direction == .previous)
        #expect(payload.boundaryBehavior.rawValue == behavior)
    }

    @Test
    func roundTripPagerStepNavigationOutcome() async throws {
        try assertRoundTrip("""
        {
            "type": "pager_step_navigation",
            "direction": "next",
            "boundary_behavior": "wrap",
            "identifier": "\(Self.oid)"
        }
        """)
    }

    // MARK: - MediaPlayback

    @Test("Decode media_playback – all commands", arguments: ["play", "pause", "toggle"])
    func decodeMediaPlaybackOutcome(command: String) async throws {
        let outcome = try decode("""
            {"type": "media_playback", "command": "\(command)", "identifier": "\(Self.oid)"}
        """)
        
        guard case .mediaPlayback(let payload) = outcome else {
            Issue.record("Expected .mediaPlayback, got \(outcome)")
            return
        }
        
        #expect(payload.command.rawValue == command)
    }

    @Test
    func roundTripMediaPlaybackOutcome() async throws {
        try assertRoundTrip("""
            {"type": "media_playback", "command": "play", "identifier": "\(Self.oid)"}
        """)
    }

    // MARK: - MediaAudio

    @Test("Decode media_audio – all commands", arguments: ["mute", "unmute", "toggle"])
    func decodeMediaAudioOutcome(command: String) async throws {
        let outcome = try decode("""
            {"type": "media_audio", "command": "\(command)", "identifier": "\(Self.oid)"}
        """)
        
        guard case .mediaAudio(let payload) = outcome else {
            Issue.record("Expected .mediaAudio, got \(outcome)")
            return
        }
        
        #expect(payload.command.rawValue == command)
    }

    @Test
    func roundTripMediaAudioOutcome() async throws {
        try assertRoundTrip("""
            {"type": "media_audio", "command": "unmute", "identifier": "\(Self.oid)"}
        """)
    }

    // MARK: - StateAction
    @Test
    func decodeStateActionOutcomeClearState() async throws {
        let json = """
        {
            "type": "state_action",
            "identifier": "\(Self.oid)",
            "action": { "type": "clear" }
        }
        """
        let outcome = try decode(json)
        guard case .stateAction(let payload) = outcome else {
            Issue.record("Expected .stateAction, got \(outcome)")
            return
        }
        guard case .clearState = payload.action else {
            Issue.record("Expected .clearState action, got \(payload.action)")
            return
        }
    }

    @Test
    func decodeStateActionOutcomeSetState() async throws {
        let json = """
        {
            "type": "state_action",
            "identifier": "\(Self.oid)",
            "action": { "type": "set", "key": "myKey", "value": "myValue" }
        }
        """
        let outcome = try decode(json)
        guard case .stateAction(let payload) = outcome else {
            Issue.record("Expected .stateAction, got \(outcome)")
            return
        }
        guard case .setState(let setState) = payload.action else {
            Issue.record("Expected .setState action, got \(payload.action)")
            return
        }
        #expect(setState.key == "myKey")
    }

    @Test
    func decodeStateActionOutcomeSetStateWithTTL() async throws {
        let json = """
        {
            "type": "state_action",
            "identifier": "\(Self.oid)",
            "action": { "type": "set", "key": "myKey", "value": 42, "ttl_seconds": 3600 }
        }
        """
        let outcome = try decode(json)
        guard case .stateAction(let payload) = outcome else {
            Issue.record("Expected .stateAction, got \(outcome)")
            return
        }
        guard case .setState(let setState) = payload.action else {
            Issue.record("Expected .setState action, got \(payload.action)")
            return
        }
        #expect(setState.key == "myKey")
        #expect(setState.ttl == 3600)
    }

    @Test
    func decodeStateActionOutcomeSetFormValue() async throws {
        let json = """
        {
            "type": "state_action",
            "identifier": "\(Self.oid)",
            "action": { "type": "set_form_value", "key": "formKey" }
        }
        """
        let outcome = try decode(json)
        guard case .stateAction(let payload) = outcome else {
            Issue.record("Expected .stateAction, got \(outcome)")
            return
        }
        guard case .formValue(let formValue) = payload.action else {
            Issue.record("Expected .formValue action, got \(payload.action)")
            return
        }
        #expect(formValue.key == "formKey")
    }

    @Test
    func roundTripStateActionClearState() async throws {
        try assertRoundTrip("""
        {
            "type": "state_action",
            "identifier": "\(Self.oid)",
            "action": { "type": "clear" }
        }
        """)
    }

    @Test
    func roundTripStateActionSetState() async throws {
        try assertRoundTrip("""
        {
            "type": "state_action",
            "identifier": "\(Self.oid)",
            "action": { "type": "set", "key": "k", "value": "v" }
        }
        """)
    }

    // MARK: - Form
    @Test("Decode form – all commands", arguments: ["validate", "submit"])
    func decodeFormOutcome(command: String) async throws {
        let outcome = try decode("""
            {"type": "form", "command": "\(command)", "identifier": "\(Self.oid)"}
        """)
        
        guard case .form(let payload) = outcome else {
            Issue.record("Expected .form, got \(outcome)")
            return
        }
        
        #expect(payload.command.rawValue == command)
    }

    @Test
    func roundTripFormOutcome() async throws {
        try assertRoundTrip("""
            {"type": "form", "command": "submit", "identifier": "\(Self.oid)"}
        """)
    }

    // MARK: - AsyncView

    @Test
    func decodeAsyncViewOutcome() async throws {
        let outcome = try decode("""
            {"type": "async_view", "command": "retry", "identifier": "\(Self.oid)"}
        """)
        
        guard case .asyncView(let payload) = outcome else {
            Issue.record("Expected .asyncView, got \(outcome)")
            return
        }
        
        #expect(payload.command == .retry)
    }

    @Test
    func roundTripAsyncViewOutcome() async throws {
        try assertRoundTrip("""
            {"type": "async_view", "command": "retry", "identifier": "\(Self.oid)"}
        """)
    }

    // MARK: - Error handling

    @Test
    func decodeUnknownTypeThrows() async throws {
        #expect(throws: (any Error).self) {
            try decode("""
                {"type": "unknown_outcome_type"}
            """)
        }
    }

    @Test
    func decodeMissingTypeThrows() async throws {
        #expect(throws: (any Error).self) {
            try decode("""
                {"command": "retry"}
            """)
        }
    }

    @Test
    func decodeMissingIdentifierThrows() async throws {
        #expect(throws: (any Error).self) {
            try decode("""
                {"type": "dismiss", "cancel": false}
            """)
        }
    }

    @Test
    func decodeEmptyObjectThrows() async throws {
        #expect(throws: (any Error).self) {
            try decode("{}")
        }
    }

    // MARK: - Equatability

    @Test
    func equalOutcomesAreEqual() async throws {
        let a = try decode("""
            {"type": "dismiss", "cancel": true, "identifier": "\(Self.oid)"}
        """)
        
        let b = try decode("""
            {"type": "dismiss", "cancel": true, "identifier": "\(Self.oid)"}
        """)
        
        #expect(a == b)
    }

    @Test
    func dismissOutcomesWithDifferentCancelAreNotEqual() async throws {
        let withCancel = try decode("""
            {"type": "dismiss", "cancel": true, "identifier": "\(Self.oid)"}
        """)
        
        let withoutCancel = try decode("""
            {"type": "dismiss", "identifier": "\(Self.oid)"}
        """)
        
        #expect(withCancel != withoutCancel)
    }

    // MARK: - Identifier

    @Test
    func dismissOutcomesWithDifferentIdentifiersAreNotEqual() async throws {
        let a = try decode("""
            {"type": "dismiss", "identifier": "x"}
        """)
        let b = try decode("""
            {"type": "dismiss", "identifier": "y"}
        """)
        #expect(a != b)
    }

    @Test
    func dismissOutcomesWithSameIdentifierAreEqual() async throws {
        let a = try decode("""
            {"type": "dismiss", "cancel": false, "identifier": "same"}
        """)
        let b = try decode("""
            {"type": "dismiss", "cancel": false, "identifier": "same"}
        """)
        #expect(a == b)
    }

    @Test
    func differentCaseOutcomesAreNotEqual() async throws {
        let dismiss = try decode("""
            {"type": "dismiss", "identifier": "d"}
        """)
        
        let form = try decode("""
            {"type": "form", "command": "submit", "identifier": "f"}
        """)
        
        #expect(dismiss != form)
    }

    // MARK: - Array helpers
    @Test
    func arrayHasFormOutcome() async throws {
        let outcomes: [ThomasOutcome] = [
            try decode("{\"type\": \"dismiss\", \"identifier\": \"a\"}"),
            try decode("""
                {"type": "form", "command": "submit", "identifier": "b"}
            """)
        ]
        #expect(outcomes.hasFormOutcome == true)
    }

    @Test
    func arrayWithNoFormOutcome() async throws {
        let outcomes: [ThomasOutcome] = [
            try decode("{\"type\": \"dismiss\", \"identifier\": \"a\"}"),
            try decode("""
                {"type": "pager_step_navigation", "direction": "next", "identifier": "b"}
            """)
        ]
        #expect(outcomes.hasFormOutcome == false)
    }

    @Test
    func arrayHasForwardOutcome() async throws {
        let outcomes: [ThomasOutcome] = [
            try decode("""
                {"type": "pager_step_navigation", "direction": "next", "identifier": "n"}
            """)
        ]
        #expect(outcomes.hasForwardOutcome == true)
    }

    @Test
    func arrayPreviousDirectionIsNotForwardOutcome() async throws {
        let outcomes: [ThomasOutcome] = [
            try decode("""
                {"type": "pager_step_navigation", "direction": "previous", "identifier": "p"}
            """)
        ]
        #expect(outcomes.hasForwardOutcome == false)
    }

    @Test
    func emptyArrayHasNoFormOrForwardOutcome() async {
        let outcomes: [ThomasOutcome] = []
        #expect(outcomes.hasFormOutcome == false)
        #expect(outcomes.hasForwardOutcome == false)
    }

    @Test
    func decodeArrayOfMixedOutcomes() async throws {
        let json = """
        [
            {"type": "dismiss", "identifier": "a"},
            {"type": "form", "command": "submit", "identifier": "b"},
            {"type": "pager_step_navigation", "direction": "next", "identifier": "c"}
        ]
        """
        let outcomes = try decoder.decode([ThomasOutcome].self, from: Data(json.utf8))
        #expect(outcomes.count == 3)

        guard case .dismiss = outcomes[0] else {
            Issue.record("Expected .dismiss at index 0")
            return
        }
        guard case .form = outcomes[1] else {
            Issue.record("Expected .form at index 1")
            return
        }
        guard case .pagerStepNavigation = outcomes[2] else {
            Issue.record("Expected .pagerStepNavigation at index 2")
            return
        }
    }

    // MARK: - Helpers

    private func decode(_ json: String) throws -> ThomasOutcome {
        try decoder.decode(ThomasOutcome.self, from: Data(json.utf8))
    }

    private func assertRoundTrip(_ json: String) throws {
        let original = try decoder.decode(ThomasOutcome.self, from: Data(json.utf8))
        let reencoded = try encoder.encode(original)
        let decoded = try decoder.decode(ThomasOutcome.self, from: reencoded)
        #expect(original == decoded)
    }
}
