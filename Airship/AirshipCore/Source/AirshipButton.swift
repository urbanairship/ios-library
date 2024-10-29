/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// Button view.
struct AirshipButton<Label> : View  where Label : View {
    @EnvironmentObject private var formState: FormState
    @EnvironmentObject private var pagerState: PagerState
    @EnvironmentObject private var viewState: ViewState
    @EnvironmentObject private var thomasEnvironment: ThomasEnvironment
    @Environment(\.layoutState) private var layoutState
    @Environment(\.isButtonActionsEnabled) private var isButtonActionsEnabled
    @Environment(\.isVoiceOverRunning) private var isVoiceOverRunning

    let identifier: String
    let reportingMetadata: AirshipJSON?
    let description: String
    let clickBehaviors:[ButtonClickBehavior]?
    let eventHandlers: [EventHandler]?
    let actions: ActionsPayload?
    let tapEffect: ButtonTapEffect?
    let useTapGestureForVoiceOver: Bool
    let label: () -> Label

    init(
        identifier: String,
        reportingMetadata: AirshipJSON? = nil,
        description: String,
        clickBehaviors: [ButtonClickBehavior]? = nil,
        eventHandlers: [EventHandler]? = nil,
        actions: ActionsPayload? = nil,
        tapEffect: ButtonTapEffect? = nil,
        useTapGestureForVoiceOver: Bool = false,
        label: @escaping () -> Label
    ) {
        self.identifier = identifier
        self.reportingMetadata = reportingMetadata
        self.description = description
        self.clickBehaviors = clickBehaviors
        self.eventHandlers = eventHandlers
        self.actions = actions
        self.tapEffect = tapEffect
        self.useTapGestureForVoiceOver = useTapGestureForVoiceOver
        self.label = label
    }

    var body: some View {
        if isVoiceOverRunning, useTapGestureForVoiceOver {
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .accessibilityElement()
                    .accessibilityLabel(self.description)
                    .accessibilityAddTraits([.isButton])
                    .accessibilityAction {
                        if (isButtonActionsEnabled) {
                            doButtonActions()
                        }
                    }
                self.label()
            }
            .accessibilityElement(children: .contain)
        } else {
            Button(
                action: {
                    if (isButtonActionsEnabled) {
                        doButtonActions()
                    }
                },
                label: self.label
            )
            .accessibilityLabel(self.description)
            .buttonTapEffect(tapEffect ?? .default)
        }
    }

    private func doButtonActions() {
        let taps = self.eventHandlers?.filter { $0.type == .tap }

        // Button reporting
        thomasEnvironment.buttonTapped(
            buttonIdentifier: self.identifier,
            reportingMetatda: self.reportingMetadata,
            layoutState: layoutState
        )

        // Buttons
        handleBehaviors(self.clickBehaviors ?? [])
        handleActions(self.actions)

        /// Tap handlers
        taps?.forEach { tap in
            handleStateActions(tap.stateActions)
        }
    }

    private func handleBehaviors(
        _ behaviors: [ButtonClickBehavior]?
    ) {
        behaviors?.sorted { first, second in
            first.sortOrder < second.sortOrder
        }.forEach { behavior in
            switch(behavior) {
            case .dismiss:
                thomasEnvironment.dismiss(
                    buttonIdentifier: self.identifier,
                    buttonDescription: self.description,
                    cancel: false,
                    layoutState: layoutState
                )

            case .cancel:
                  thomasEnvironment.dismiss(
                    buttonIdentifier: self.identifier,
                    buttonDescription: self.description,
                    cancel: true,
                    layoutState: layoutState
                  )

            case .pagerNext:
                pagerState.pageRequest = .next

            case .pagerPrevious:
                pagerState.pageRequest = .back

            case .pagerNextOrDismiss:
                if pagerState.isLastPage {
                    thomasEnvironment.dismiss(
                        buttonIdentifier: self.identifier,
                        buttonDescription: self.description,
                        cancel: false,
                        layoutState: layoutState
                    )
                } else {
                    pagerState.pageRequest = .next
                }

            case .pagerNextOrFirst:
                if pagerState.isLastPage {
                    pagerState.pageRequest = .first
                } else {
                    pagerState.pageRequest = .next
                }

            case .pagerPause:
                pagerState.pause()

            case .pagerResume:
                pagerState.resume()

            case .formSubmit:
                let formState = formState.topFormState
                thomasEnvironment.submitForm(formState, layoutState: layoutState)
                formState.markSubmitted()
            }
        }
    }

    private func handleActions(_ actionPayload: ActionsPayload?) {
        if let actionPayload {
            thomasEnvironment.runActions(actionPayload, layoutState: layoutState)
        }
    }

    private func handleStateActions(_ stateActions: [StateAction]) {
        stateActions.forEach { action in
            switch action {
            case .setState(let details):
                viewState.updateState(
                    key: details.key,
                    value: details.value?.unWrap()
                )
            case .clearState:
                viewState.clearState()
            case .formValue(_):
                AirshipLogger.error("Unable to process form value")
            }
        }
    }
}


fileprivate struct AirshipButtonEmptyStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

fileprivate extension View {
    @ViewBuilder
    func buttonTapEffect(_ tapEffect: ButtonTapEffect) -> some View {
        switch(tapEffect) {
        case .default:
            self.buttonStyle(.plain)
        case .none:
            self.buttonStyle(AirshipButtonEmptyStyle())
        }
    }
}
