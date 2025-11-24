/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// Button view.
struct AirshipButton<Label> : View  where Label : View {
    @EnvironmentObject private var formState: ThomasFormState
    @EnvironmentObject private var pagerState: PagerState
    @EnvironmentObject private var thomasState: ThomasState
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

    @State
    var isProcessing: Bool = false

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
                    Task { @MainActor in
                        isProcessing = true
                        await doButtonActions()
                        isProcessing = false
                    }
                }
            },
            label: self.label
        )
        .optionalAccessibilityLabel(self.description)
        .buttonTapEffect(tapEffect ?? .default)
        .disabled(isProcessing)
    }

    @MainActor
    private func doButtonActions() async {
        if clickBehaviors?.contains(.formSubmit) == true || clickBehaviors?.contains(.formValidate) == true {
            guard await formState.validate() else { return }
        }

        let taps = self.eventHandlers?.filter { $0.type == .tap }
        if let taps, !taps.isEmpty {
            /// Tap handlers
            taps.forEach { tap in
                handleStateActions(tap.stateActions)
            }

            // WORKAROUND: SwiftUI state updates are not immediately available to child views.
            // Yielding allows the state changes to propagate through the view hierarchy
            // before executing behaviors that may depend on the updated state.
            await Task.yield()
        }

        // Button reporting
        thomasEnvironment.buttonTapped(
            buttonIdentifier: self.identifier,
            reportingMetadata: self.reportingMetadata,
            layoutState: layoutState
        )

        // Buttons
        await handleBehaviors(self.clickBehaviors ?? [])
        handleActions(self.actions)
    }

    private func handleBehaviors(
        _ behaviors: [ThomasButtonClickBehavior]?
    ) async {
        guard let behaviors else { return }

        for behavior in behaviors {
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

            case .pagerPauseToggle:
                pagerState.togglePause()

            case .formValidate:
                // Already handled above
                break
                
            case .formSubmit:
                do {
                    try await formState.submit(layoutState: layoutState)
                } catch {
                    AirshipLogger.error("Failed to submit \(error)")
                }
            }
        }
    }

    private func handleActions(_ actionPayload: ThomasActionsPayload?) {
        if let actionPayload {
            thomasEnvironment.runActions(actionPayload, layoutState: layoutState)
        }
    }

    private func handleStateActions(_ stateActions: [ThomasStateAction]) {
        thomasState.processStateActions(stateActions)
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
