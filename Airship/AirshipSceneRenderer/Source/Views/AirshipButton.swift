/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
@_spi(AirshipInternal) import AirshipBasement

/// Button view.
struct AirshipButton<Label> : View  where Label : View {
    @EnvironmentObject private var formState: ThomasFormState
    @EnvironmentObject private var pagerState: PagerState
    @EnvironmentObject private var videoState: VideoState
    @EnvironmentObject private var thomasState: ThomasState
    @EnvironmentObject private var thomasEnvironment: ThomasEnvironment
    @EnvironmentObject private var asyncViewState: ThomasAsyncViewState

    @Environment(\.layoutState) private var layoutState
    @Environment(\.isButtonActionsEnabled) private var isButtonActionsEnabled

    private let identifier: String
    private let reportingMetadata: AirshipJSON?
    private let description: String?
    private let outcomes: [ThomasOutcome]
    private let eventHandlers: [ThomasEventHandler]?
    private let tapEffect: ThomasButtonTapEffect?
    private let label: () -> Label

    @State
    private var isProcessing: Bool = false

    init(
        identifier: String,
        reportingMetadata: AirshipJSON? = nil,
        description: String?,
        outcomes: [ThomasOutcome] = [],
        eventHandlers: [ThomasEventHandler]? = nil,
        tapEffect: ThomasButtonTapEffect? = nil,
        label: @escaping () -> Label
    ) {
        self.identifier = identifier
        self.reportingMetadata = reportingMetadata
        self.description = description
        self.outcomes = outcomes
        self.eventHandlers = eventHandlers
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
        // Inside .disabled so the reporter sees isEnabled == false while processing and
        // stops reporting, matching the disabled-elements-don't-report rule.
        .reportPagerGestureExclusion()
        .disabled(isProcessing)
    }

    @MainActor
    private func doButtonActions() async {
        await ThomasButtonTap(
            identifier: identifier,
            description: description,
            reportingMetadata: reportingMetadata,
            outcomes: outcomes,
            eventHandlers: eventHandlers
        ).perform(
            formState: formState,
            thomasState: thomasState,
            thomasEnvironment: thomasEnvironment,
            layoutState: layoutState
        )
    }
}

/// A button tap: validates the form, reports the tap, then processes the tap handlers' and button's outcomes.
@MainActor
struct ThomasButtonTap {
    let identifier: String
    let description: String?
    let reportingMetadata: AirshipJSON?
    let outcomes: [ThomasOutcome]
    let eventHandlers: [ThomasEventHandler]?

    /// Performs the tap.
    ///
    /// Tap-handler outcomes run ahead of the button's own, and a form submit runs before both;
    /// see ``ThomasState/processButtonOutcomes(_:submit:dismiss:runActions:)``.
    ///
    /// - Parameters:
    ///   - formState: The form the button submits or validates.
    ///   - thomasState: The state outcomes apply to.
    ///   - thomasEnvironment: Receives the reporting, dismiss and actions.
    ///   - layoutState: The layout state reported with events, including the button state.
    func perform(
        formState: ThomasFormState,
        thomasState: ThomasState,
        thomasEnvironment: ThomasEnvironment,
        layoutState: LayoutState
    ) async {
        // Tapping a Button does not resign the keyboard in SwiftUI, so a focused text
        // input stays first responder — and once we navigate, UIKit keyboard-avoidance
        // scrolls the pager back to reveal it (the snap-back). Clear the layout's focus
        // now, before form validation may await async work and before navigation. Local
        // to this layout, so always safe.
        thomasEnvironment.focusedID = nil

        var resolved = EventHandlerViewModifier.outcomes(for: eventHandlers ?? [], type: .tap) + outcomes

        // Outside a form the environment's placeholder form never validates, so form outcomes are
        // dropped and the rest still run, as on Android.
        if layoutState.formState == nil {
            resolved = resolved.filter {
                if case .form = $0 { return false }
                return true
            }
        }

        if resolved.hasFormOutcome {
            guard await formState.validate() else { return }
        }

        thomasEnvironment.buttonTapped(
            buttonIdentifier: identifier,
            reportingMetadata: reportingMetadata,
            layoutState: layoutState
        )

        let dismissDescription = description ?? identifier
        await thomasState.processButtonOutcomes(
            resolved,
            submit: {
                do {
                    try await formState.submit(
                        layoutState: layoutState,
                        thomasState: thomasState
                    )
                    return true
                } catch {
                    AirshipLogger.error("Failed to submit \(error)")
                    return false
                }
            },
            dismiss: { [identifier] outcome in
                thomasEnvironment.dismiss(
                    buttonIdentifier: identifier,
                    buttonDescription: dismissDescription,
                    cancel: outcome.cancel ?? false,
                    layoutState: layoutState
                )
            },
            runActions: { outcome in
                thomasEnvironment.runActions(outcome.actions, layoutState: layoutState)
            }
        )
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
        @Environment(\.isFocused) private var isFocused
        @Environment(\.isEnabled) private var isEnabled

        fileprivate let configuration: ButtonStyle.Configuration

        var body: some View {
            configuration.label
                .hoverEffect(.highlight, isEnabled: isFocused)
                .colorMultiply(isEnabled ? Color.white : ThomasConstants.disabledColor)
        }
    }
}

#endif
