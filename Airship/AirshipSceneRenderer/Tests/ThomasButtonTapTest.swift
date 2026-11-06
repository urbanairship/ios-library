/* Copyright Airship and Contributors */

import Foundation
import Testing
@_spi(AirshipInternal) import AirshipBasement

@testable @_spi(AirshipInternal) import AirshipSceneRenderer

@Suite("Button tap", .timeLimit(.minutes(1)))
@MainActor
struct ThomasButtonTapTest {
    private let delegate = ButtonTapTestDelegate()
    private let thomasState = ThomasState(onStateChange: { _ in })
    private let formState = ThomasFormState(
        identifier: "form",
        formType: .form,
        formResponseType: nil,
        validationMode: .onDemand
    )

    private var environment: ThomasEnvironment {
        ThomasEnvironment(delegate: delegate, extensions: TestThomasExtensions())
    }

    private var formLayoutState: LayoutState {
        LayoutState.empty.override(formState: formState)
    }

    private func makeFormValid() {
        formState.onSubmit = { _, _, _ in }
        formState.updateField(
            .validField(identifier: "field", input: .email(nil), result: .init(value: .email("valid email")))
        )
    }

    private func tap(
        outcomes: [ThomasOutcome],
        eventHandlers: [ThomasEventHandler]? = nil,
        layoutState: LayoutState
    ) async {
        await ThomasButtonTap(
            identifier: "button",
            description: nil,
            reportingMetadata: nil,
            outcomes: outcomes,
            eventHandlers: eventHandlers
        ).perform(
            formState: formState,
            thomasState: thomasState,
            thomasEnvironment: environment,
            layoutState: layoutState
        )
    }

    @Test
    func dismissReportsSubmittedForm() async {
        makeFormValid()

        await tap(outcomes: [submit, dismiss], layoutState: formLayoutState)

        #expect(delegate.events == ["button_tap", "dismiss(submitted: true)"])
        #expect(delegate.dismissals == [false])
        #expect(formState.status == .submitted)
    }

    @Test
    func tapHandlerDismissRunsAfterSubmit() async {
        makeFormValid()
        let handlers: [ThomasEventHandler] = [
            .init(type: .tap, stateActions: [], outcomes: [dismiss])
        ]

        await tap(outcomes: [submit], eventHandlers: handlers, layoutState: formLayoutState)

        #expect(delegate.events == ["button_tap", "dismiss(submitted: true)"])
    }

    @Test
    func invalidFormRunsNothing() async {
        formState.onSubmit = { _, _, _ in }
        formState.updateField(.invalidField(identifier: "field", input: .email(nil)))

        await tap(outcomes: [submit, dismiss], layoutState: formLayoutState)

        #expect(delegate.events.isEmpty)
        #expect(delegate.dismissals.isEmpty)
    }

    @Test
    func outsideFormDropsFormOutcomesAndRunsTheRest() async {
        await tap(outcomes: [submit, dismiss], layoutState: .empty)

        #expect(delegate.events == ["button_tap", "dismiss"])
        #expect(delegate.dismissals == [false])
    }
}

private let submit = ThomasOutcome.form(.init(command: .submit, identifier: "submit"))
private let dismiss = ThomasOutcome.dismiss(.init(cancel: false, identifier: "dismiss"))

@MainActor
private final class ButtonTapTestDelegate: ThomasDelegate {
    var events: [String] = []
    var dismissals: [Bool] = []

    func onVisibilityChanged(isVisible: Bool, isForegrounded: Bool) {}

    func onReportingEvent(_ event: ThomasReportingEvent) {
        switch event {
        case .buttonTap:
            events.append("button_tap")
        case .dismiss(_, _, let context):
            if let form = context.form {
                events.append("dismiss(submitted: \(form.submitted))")
            } else {
                events.append("dismiss")
            }
        default:
            break
        }
    }

    func onDismissed(cancel: Bool) {
        dismissals.append(cancel)
    }
}
