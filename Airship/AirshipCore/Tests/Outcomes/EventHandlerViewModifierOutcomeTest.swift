/* Copyright Airship and Contributors */

import Foundation
import Testing
@_spi(AirshipInternal) import AirshipBasement

@testable import AirshipCore

@Suite("Outcomes", .timeLimit(.minutes(1)))
@MainActor
struct EventHandlerViewModifierOutcomeTest {

    @Test
    func outcomesFlattensMatchingHandlersInOrder() {
        let handlers: [ThomasEventHandler] = [
            .init(type: .formInput, stateActions: [.clearState], outcomes: nil),
            .init(
                type: .tap,
                stateActions: [],
                outcomes: [.dismiss(.init(cancel: false, identifier: "eh.dismiss.false"))]
            ),
            .init(
                type: .tap,
                stateActions: [.setState(.init(key: "a", value: .number(1), ttl: nil))],
                outcomes: nil
            ),
        ]
        let tapOutcomes = EventHandlerViewModifier.outcomes(for: handlers, type: .tap)
        #expect(tapOutcomes.count == 2)
        guard case .dismiss(let d0) = tapOutcomes[0] else {
            Issue.record("Expected dismiss first")
            return
        }
        #expect(d0.cancel == false)
        guard case .stateAction(let s1) = tapOutcomes[1] else {
            Issue.record("Expected state action second")
            return
        }
        if case .setState(let inner) = s1.action {
            #expect(inner.key == "a")
        } else {
            Issue.record("Expected setState")
        }
    }

    @Test
    func outcomesPrefersHandlerOutcomesOverStateActions() {
        let handlers: [ThomasEventHandler] = [
            .init(
                type: .tap,
                stateActions: [.clearState],
                outcomes: [.dismiss(.init(cancel: true, identifier: "eh.dismiss.true"))]
            ),
        ]
        let tapOutcomes = EventHandlerViewModifier.outcomes(for: handlers, type: .tap)
        #expect(tapOutcomes.count == 1)
        guard case .dismiss(let d) = tapOutcomes[0] else {
            Issue.record("Expected dismiss")
            return
        }
        #expect(d.cancel == true)
    }

    @Test
    func processOutcomesDelegatesDismissToEnvironment() async {
        let delegate = EventHandlerOutcomeTestDelegate()
        let timer = EventHandlerOutcomeTestTimer()
        let env = ThomasEnvironment(delegate: delegate, extensions: nil, pagerTracker: nil, timer: timer, onDismiss: nil)
        let thomasState = ThomasState(mutableState: .init(initialState: [:]), onStateChange: { _ in })

        await EventHandlerViewModifier.processOutcomes(
            [.dismiss(.init(cancel: true, identifier: "eh.process.dismiss"))],
            thomasState: thomasState,
            thomasEnvironment: env,
            layoutState: .empty
        )

        #expect(delegate.dismissals == [true])
        #expect(env.isDismissed == true)
    }
}

// MARK: - Local test doubles
// ThomasEnvironmentTest.swift defines similar types but is not part of the AirshipTests compile sources.

@MainActor
private final class EventHandlerOutcomeTestDelegate: ThomasDelegate {
    var dismissals: [Bool] = []

    func onVisibilityChanged(isVisible: Bool, isForegrounded: Bool) {}

    func onReportingEvent(_ event: ThomasReportingEvent) {}

    func onDismissed(cancel: Bool) {
        dismissals.append(cancel)
    }
}

@MainActor
private final class EventHandlerOutcomeTestTimer: AirshipTimerProtocol {
    var time: TimeInterval = 0

    func start() {}

    func stop() {}
}
