/* Copyright Airship and Contributors */

import Foundation
import Testing

@testable import AirshipBasement
@testable @_spi(AirshipInternal) import AirshipSceneRenderer

@Suite("Outcomes", .timeLimit(.minutes(2)))
struct ThomasPageControllerCompletionOutcomeTest {

    private let decoder = JSONDecoder()

    @Test
    func decodeOutcomesField() throws {
        let json = """
        {
          "pager_completions": [
            {
              "outcomes": [
                { "type": "dismiss", "cancel": false, "identifier": "branch.dismiss" }
              ]
            }
          ]
        }
        """
        let branching = try decoder.decode(ThomasPagerControllerBranching.self, from: Data(json.utf8))
        #expect(branching.completions.first?.outcomes?.count == 1)
    }

    @Test
    func decodeStateActionsOnlyBackwardCompat() throws {
        let json = """
        {
          "pager_completions": [
            {
              "state_actions": [
                { "type": "clear" }
              ]
            }
          ]
        }
        """
        let branching = try decoder.decode(ThomasPagerControllerBranching.self, from: Data(json.utf8))
        #expect(branching.completions.first?.stateActions?.count == 1)
        #expect(branching.completions.first?.outcomes == nil)
    }

    @MainActor
    @Test
    func completionProcessesOutcomesWhenPresent() async throws {
        let marker = "completion_outcome_marker"
        let mutableState = ThomasState.MutableState(initialState: .object([:]))
        let outcome = ThomasStateAction.setState(
            .init(key: marker, value: .string("done"), ttl: nil)
        ).asOutcome
        let branching = ThomasPagerControllerBranching(completions: [
            ThomasPageControllerCompletion(predicate: nil, stateActions: nil, outcomes: [outcome])
        ])
        let pagerState = PagerState(identifier: "p", branching: branching)
        let thomasState = ThomasState(
            pagerState: pagerState,
            mutableState: mutableState,
            onStateChange: { _ in }
        )
        pagerState.setPagesAndListenForUpdates(
            pages: [Self.makePage(id: "page-1")],
            thomasState: thomasState,
            swipeDisableSelectors: nil
        )
        try await Self.pollForOutcome(on: mutableState, key: marker)
        #expect(mutableState.state.object?[marker] == .string("done"))
    }

    @MainActor
    @Test
    func completionPrefersOutcomesOverStateActions() async throws {
        let outcomeKey = "from_outcomes"
        let stateKey = "from_state_actions"
        let mutableState = ThomasState.MutableState(initialState: .object([:]))
        let branching = ThomasPagerControllerBranching(completions: [
            ThomasPageControllerCompletion(
                predicate: nil,
                stateActions: [.setState(.init(key: stateKey, value: .bool(true), ttl: nil))],
                outcomes: [ThomasStateAction.setState(.init(key: outcomeKey, value: .bool(true), ttl: nil)).asOutcome]
            )
        ])
        let pagerState = PagerState(identifier: "p", branching: branching)
        let thomasState = ThomasState(
            pagerState: pagerState,
            mutableState: mutableState,
            onStateChange: { _ in }
        )
        pagerState.setPagesAndListenForUpdates(
            pages: [Self.makePage(id: "page-1")],
            thomasState: thomasState,
            swipeDisableSelectors: nil
        )
        try await Self.pollForOutcome(on: mutableState, key: outcomeKey)
        #expect(mutableState.state.object?[outcomeKey] == .bool(true))
        #expect(mutableState.state.object?[stateKey] == nil)
    }

    @MainActor
    @Test
    func completionMapsStateActionsWhenOutcomesNil() async throws {
        let marker = "completion_state_action_marker"
        let mutableState = ThomasState.MutableState(initialState: .object([:]))
        let branching = ThomasPagerControllerBranching(completions: [
            ThomasPageControllerCompletion(
                predicate: nil,
                stateActions: [.setState(.init(key: marker, value: .bool(true), ttl: nil))],
                outcomes: nil
            )
        ])
        let pagerState = PagerState(identifier: "p", branching: branching)
        let thomasState = ThomasState(
            pagerState: pagerState,
            mutableState: mutableState,
            onStateChange: { _ in }
        )
        pagerState.setPagesAndListenForUpdates(
            pages: [Self.makePage(id: "page-1")],
            thomasState: thomasState,
            swipeDisableSelectors: nil
        )
        try await Self.pollForOutcome(on: mutableState, key: marker)
        #expect(mutableState.state.object?[marker] == .bool(true))
    }

    @MainActor
    @Test
    func completionDoesNotRunWhenPredicateFails() async throws {
        let marker = "should_not_apply"
        let predicate = JSONPredicate(jsonMatcher: JSONMatcher(
            valueMatcher: .matcherWhereBooleanEquals(true),
            scope: ["gate"]
        ))
        let mutableState = ThomasState.MutableState(initialState: .object([:]))
        let branching = ThomasPagerControllerBranching(completions: [
            ThomasPageControllerCompletion(
                predicate: predicate,
                stateActions: [.setState(.init(key: marker, value: .bool(true), ttl: nil))],
                outcomes: nil
            )
        ])
        let pagerState = PagerState(identifier: "p", branching: branching)
        let thomasState = ThomasState(
            pagerState: pagerState,
            mutableState: mutableState,
            onStateChange: { _ in }
        )
        pagerState.setPagesAndListenForUpdates(
            pages: [Self.makePage(id: "page-1")],
            thomasState: thomasState,
            swipeDisableSelectors: nil
        )
        try await Task.sleep(nanoseconds: 150_000_000)
        #expect(mutableState.state.object?[marker] == nil)
    }

    private static func makePage(id: String) -> ThomasViewInfo.Pager.Item {
        ThomasViewInfo.Pager.Item(
            identifier: id,
            view: .emptyView(.init(commonProperties: .init(), properties: .init())),
            displayActions: nil,
            automatedActions: nil,
            accessibilityActions: nil,
            stateActions: nil,
            displayOutcomes: nil,
            branching: nil
        )
    }

    @MainActor
    private static func pollForOutcome(on mutableState: ThomasState.MutableState, key: String) async throws {
        for _ in 0..<100 {
            if mutableState.state.object?[key] != nil { return }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        Issue.record("Timed out waiting for state key \(key)")
    }
}
