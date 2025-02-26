/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// Button view.
struct AirshipButton<Label> : View  where Label : View {
    @EnvironmentObject private var formState: ThomasFormState
    @EnvironmentObject private var pagerState: PagerState
    @EnvironmentObject private var viewState: ViewState
    @EnvironmentObject private var thomasEnvironment: ThomasEnvironment
    @Environment(\.layoutState) private var layoutState
    @Environment(\.isButtonActionsEnabled) private var isButtonActionsEnabled

    let identifier: String
    let reportingMetadata: AirshipJSON?
    let description: String?
    let clickBehaviors: [ThomasButtonClickBehavior]?
    let eventHandlers: [ThomasEventHandler]?
    let actions: ThomasActionsPayload?
    let tapEffect: ThomasButtonTapEffect?
    let label: () -> Label

    init(
        identifier: String,
        reportingMetadata: AirshipJSON? = nil,
        description: String?,
        clickBehaviors: [ThomasButtonClickBehavior]? = nil,
        eventHandlers: [ThomasEventHandler]? = nil,
        actions: ThomasActionsPayload? = nil,
        tapEffect: ThomasButtonTapEffect? = nil,
        label: @escaping () -> Label
    ) {
        self.identifier = identifier
        self.reportingMetadata = reportingMetadata
        self.description = description
        self.clickBehaviors = clickBehaviors
        self.eventHandlers = eventHandlers
        self.actions = actions
        self.tapEffect = tapEffect
        self.label = label
    }

    var body: some View {
        Button(
            action: {
                if (isButtonActionsEnabled) {
                    doButtonActions()
                }
            },
            label: self.label
        )
        .optionalAccessibilityLabel(self.description)
        .buttonTapEffect(tapEffect ?? .default)
    }

    private func doButtonActions() {
        let taps = self.eventHandlers?.filter { $0.type == .tap }

        /// Tap handlers
        taps?.forEach { tap in
            handleStateActions(tap.stateActions)
        }

        // Button reporting
        thomasEnvironment.buttonTapped(
            buttonIdentifier: self.identifier,
            reportingMetatda: self.reportingMetadata,
            layoutState: layoutState
        )

        // Buttons
        handleBehaviors(self.clickBehaviors ?? [])
        handleActions(self.actions)
    }

    private func handleBehaviors(
        _ behaviors: [ThomasButtonClickBehavior]?
    ) {
        behaviors?.sorted { first, second in
            first.sortOrder < second.sortOrder
        }.forEach { behavior in
            switch(behavior) {
            case .dismiss:
                thomasEnvironment.dismiss(
                    buttonIdentifier: self.identifier,
                    buttonDescription: self.description ?? self.identifier,
                    cancel: false,
                    layoutState: layoutState
                )

            case .cancel:
                  thomasEnvironment.dismiss(
                    buttonIdentifier: self.identifier,
                    buttonDescription: self.description ?? self.identifier,
                    cancel: true,
                    layoutState: layoutState
                  )

            case .pagerNext:
                pagerState.process(request: .next)

            case .pagerPrevious:
                pagerState.process(request: .back)

            case .pagerNextOrDismiss:
                if pagerState.isLastPage {
                    thomasEnvironment.dismiss(
                        buttonIdentifier: self.identifier,
                        buttonDescription: self.description ?? self.identifier,
                        cancel: false,
                        layoutState: layoutState
                    )
                } else {
                    pagerState.process(request: .next)
                }

            case .pagerNextOrFirst:
                if pagerState.isLastPage {
                    pagerState.process(request: .first)
                } else {
                    pagerState.process(request: .next)
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

    private func handleActions(_ actionPayload: ThomasActionsPayload?) {
        if let actionPayload {
            thomasEnvironment.runActions(actionPayload, layoutState: layoutState)
        }
    }

    private func handleStateActions(_ stateActions: [ThomasStateAction]) {
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
    func buttonTapEffect(_ tapEffect: ThomasButtonTapEffect) -> some View {
        switch(tapEffect) {
        case .default:
#if os(tvOS)
            self.buttonStyle(TVButtonStyle())
#else
            self.buttonStyle(.plain)
#endif
        case .none:
            self.buttonStyle(AirshipButtonEmptyStyle())
        }
    }

    @ViewBuilder
    func optionalAccessibilityLabel(_ label: String?) -> some View {
        if let label {
            self.accessibilityLabel(label)
        } else {
            self
        }
    }


}

#if os(tvOS)
struct TVButtonStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        return ButtonView(configuration: configuration)
    }

    struct ButtonView: View {
        @Environment(\.isFocused) var isFocused
        @Environment(\.isEnabled) var isEnabled

        let configuration: ButtonStyle.Configuration

        var body: some View {
            configuration.label
                .hoverEffect(.highlight, isEnabled: isFocused)
                .colorMultiply(isEnabled ? Color.white : ThomasConstants.disabledColor)
        }
    }
}

#endif
