/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
@_spi(AirshipInternal) import AirshipBasement

/// Button layout view.
struct ButtonLayout : View {
    @Environment(\.isVoiceOverRunning) private var isVoiceOverRunning
    @Environment(\.layoutState) private var layoutState
    @EnvironmentObject private var formState: ThomasFormState
    @EnvironmentObject private var pagerState: PagerState
    @EnvironmentObject private var videoState: VideoState
    @EnvironmentObject private var thomasState: ThomasState
    @EnvironmentObject private var thomasEnvironment: ThomasEnvironment
    @EnvironmentObject private var asyncViewState: ThomasAsyncViewState

    @State private var actionTask: Task<Void, Never>?

    private let info: ThomasViewInfo.ButtonLayout
    private let constraints: ViewConstraints

    init(info: ThomasViewInfo.ButtonLayout, constraints: ViewConstraints) {
        self.info = info
        self.constraints = constraints
    }

    private var isButtonForAccessibility: Bool {
        guard let role = info.properties.accessibilityRole else {
            // Default to button
            return true
        }

        return switch(role) {
        case .container:
            false
        case .button:
            true
        }
    }

    var body: some View {
        if isVoiceOverRunning, !isButtonForAccessibility {
            // Container mode
            if let contentDescription = thomasEnvironment.resolveContentDescription(for: info.accessible) {
                // Container WITH content description: Add accessibility action
                thomasEnvironment.viewFactory.createView(self.info.properties.view, constraints: constraints)
                    .thomasBackgrounds(info.properties.backgrounds)
                    .thomasCommon(self.info, scope: [.background, .visibility])
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(contentDescription)
                    .accessibilityAction(named: contentDescription) {
                        let previousTask = actionTask
                        actionTask = Task { @MainActor in
                            await previousTask?.value
                            await performButtonAction()
                        }
                    }
                    .accessibilityHidden(info.accessible.accessibilityHidden ?? false)
            } else {
                // Container WITHOUT content description: Transparent parent
                thomasEnvironment.viewFactory.createView(self.info.properties.view, constraints: constraints)
                    .thomasBackgrounds(info.properties.backgrounds)
                    .thomasCommon(self.info, scope: [.background, .visibility])
                    .accessibilityHidden(info.accessible.accessibilityHidden ?? false)
            }
        } else {
            AirshipButton(
                identifier: self.info.properties.identifier,
                reportingMetadata: self.info.properties.reportingMetadata,
                description: thomasEnvironment.resolveContentDescription(for: self.info.accessible),
                outcomes: makeOutcomes(),
                eventHandlers: self.info.commonProperties.eventHandlers,
                tapEffect: self.info.properties.tapEffect
            ) {
                thomasEnvironment.viewFactory.createView(self.info.properties.view, constraints: constraints)
                    .thomasBackgrounds(info.properties.backgrounds)
                    .thomasCommon(self.info, scope: [.background])
                    .background(Color.airshipTappableClear)
            }
            .thomasCommon(self.info, scope: [.enableBehaviors, .visibility])
            .environment(
                \.layoutState,
                 layoutState.override(
                    buttonState: ButtonState(identifier: self.info.properties.identifier)
                 )
            )
            .accessibilityHidden(info.accessible.accessibilityHidden ?? false)
        }
    }

    @MainActor
    private func performButtonAction() async {
        let identifier = info.properties.identifier
        await ThomasButtonTap(
            identifier: identifier,
            description: thomasEnvironment.resolveContentDescription(for: info.accessible),
            reportingMetadata: info.properties.reportingMetadata,
            outcomes: makeOutcomes(),
            eventHandlers: info.commonProperties.eventHandlers
        ).perform(
            formState: formState,
            thomasState: thomasState,
            thomasEnvironment: thomasEnvironment,
            layoutState: layoutState.override(buttonState: ButtonState(identifier: identifier))
        )
    }
    
    private func makeOutcomes() -> [ThomasOutcome] {
        if let outcomes = info.properties.outcomes {
            return outcomes
        }
        
        let behavior = info.properties.clickBehaviors?.map(\.asOutcome) ?? []
        
        if let actions = info.properties.actions?.asOutcome() {
            return behavior + [actions]
        }
        
        return behavior
    }
}
