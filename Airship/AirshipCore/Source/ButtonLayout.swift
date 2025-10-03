/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// Button layout view.
struct ButtonLayout : View {
    @Environment(\.isVoiceOverRunning) private var isVoiceOverRunning
    @Environment(\.layoutState) var layoutState
    @EnvironmentObject private var formState: ThomasFormState
    @EnvironmentObject private var pagerState: PagerState
    @EnvironmentObject private var thomasState: ThomasState
    @EnvironmentObject private var thomasEnvironment: ThomasEnvironment

    @State private var actionTask: Task<Void, Never>?

    let info: ThomasViewInfo.ButtonLayout
    let constraints: ViewConstraints

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
            if let contentDescription = info.accessible.resolveContentDescription {
                // Container WITH content description: Add accessibility action
                ViewFactory.createView(self.info.properties.view, constraints: constraints)
                    .thomasBackground(
                        color: self.info.commonProperties.backgroundColor,
                        colorOverrides: self.info.commonOverrides?.backgroundColor,
                        border: self.info.commonProperties.border,
                        borderOverrides: self.info.commonOverrides?.border
                    )
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
                ViewFactory.createView(self.info.properties.view, constraints: constraints)
                    .thomasBackground(
                        color: self.info.commonProperties.backgroundColor,
                        colorOverrides: self.info.commonOverrides?.backgroundColor,
                        border: self.info.commonProperties.border,
                        borderOverrides: self.info.commonOverrides?.border
                    )
                    .accessibilityHidden(info.accessible.accessibilityHidden ?? false)
            }
        } else {
            AirshipButton(
                identifier: self.info.properties.identifier,
                reportingMetadata: self.info.properties.reportingMetadata,
                description: self.info.accessible.resolveContentDescription,
                clickBehaviors: self.info.properties.clickBehaviors,
                eventHandlers: self.info.commonProperties.eventHandlers,
                actions: self.info.properties.actions,
                tapEffect: self.info.properties.tapEffect
            ) {
                ViewFactory.createView(self.info.properties.view, constraints: constraints)
                    .thomasBackground(
                        color: self.info.commonProperties.backgroundColor,
                        colorOverrides: self.info.commonOverrides?.backgroundColor,
                        border: self.info.commonProperties.border,
                        borderOverrides: self.info.commonOverrides?.border
                    )
                    .background(Color.airshipTappableClear)
            }
            .thomasEnableBehaviors(self.info.commonProperties.enabled)
            .thomasVisibility(self.info.commonProperties.visibility)
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
        // Form validation
        if info.properties.clickBehaviors?.contains(.formSubmit) == true ||
           info.properties.clickBehaviors?.contains(.formValidate) == true {
            guard await formState.validate() else { return }
        }

        // Tap event handlers
        let taps = info.commonProperties.eventHandlers?.filter { $0.type == .tap }
        if let taps, !taps.isEmpty {
            taps.forEach { tap in
                thomasState.processStateActions(tap.stateActions)
            }
            await Task.yield()
        }

        // Button reporting
        thomasEnvironment.buttonTapped(
            buttonIdentifier: info.properties.identifier,
            reportingMetadata: info.properties.reportingMetadata,
            layoutState: layoutState
        )

        // Click behaviors
        await handleBehaviors(info.properties.clickBehaviors ?? [])

        // Actions
        handleActions(info.properties.actions)
    }

    private func handleBehaviors(_ behaviors: [ThomasButtonClickBehavior]) async {
        for behavior in behaviors {
            switch(behavior) {
            case .dismiss:
                thomasEnvironment.dismiss(
                    buttonIdentifier: info.properties.identifier,
                    buttonDescription: info.accessible.resolveContentDescription ?? info.properties.identifier,
                    cancel: false,
                    layoutState: layoutState
                )

            case .cancel:
                thomasEnvironment.dismiss(
                    buttonIdentifier: info.properties.identifier,
                    buttonDescription: info.accessible.resolveContentDescription ?? info.properties.identifier,
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
                        buttonIdentifier: info.properties.identifier,
                        buttonDescription: info.accessible.resolveContentDescription ?? info.properties.identifier,
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

            case .formValidate:
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
}
