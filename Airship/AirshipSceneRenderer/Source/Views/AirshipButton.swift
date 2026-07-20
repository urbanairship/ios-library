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
        // Tapping a Button does not resign the keyboard in SwiftUI, so a focused text
        // input stays first responder — and once we navigate, UIKit keyboard-avoidance
        // scrolls the pager back to reveal it (the snap-back). Ask focused inputs to
        // resign now, before form validation may await async work and before navigation.
        // Local to this layout, so always safe to request.
        thomasEnvironment.requestKeyboardDismiss()

        if outcomes.hasFormOutcome {
            guard await formState.validate() else { return }
        }
        
        let taps = self.eventHandlers?.filter { $0.type == .tap }
        if let taps, !taps.isEmpty {
            
            let outcomes = taps.flatMap { handler in
                handler.outcomes ?? handler.stateActions.map(\.asOutcome)
            }
            
            await thomasState.process(outcomes: outcomes)
            
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
        
        var asyncTasks: [Task<Void, Never>] = []
        
        await thomasState.process(outcomes: outcomes) { delegated in
            switch(delegated) {
            case .dismiss(let outcome):
                thomasEnvironment.dismiss(
                    buttonIdentifier: self.identifier,
                    buttonDescription: self.description ?? self.identifier,
                    cancel: outcome.cancel ?? false,
                    layoutState: layoutState
                )
            case .formAction(let outcome):
                switch(outcome.command) {
                case .validate: break //already handled above
                case .submit:
                    asyncTasks.append(Task {
                        do {
                            try await formState.submit(layoutState: layoutState)
                        } catch {
                            AirshipLogger.error("Failed to submit \(error)")
                        }
                    })
                }
            case .runAction(let outcome):
                self.thomasEnvironment
                    .runActions(outcome.actions, layoutState: self.layoutState)
            }
        }
        
        for task in asyncTasks {
            await task.value
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
