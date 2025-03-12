/* Copyright Airship and Contributors */

import Combine
import Foundation
import SwiftUI

internal struct FormSubmissionEnableBehavior: ViewModifier {
    let onApply: ((Bool, ThomasEnableBehavior) -> Void)?

    @EnvironmentObject var formState: ThomasFormState

    @ViewBuilder
    func body(content: Content) -> some View {
        if let onApply = onApply {
            content.onReceive(self.formState.$status) { value in
                onApply(value != .submitted, .formSubmission)
            }
        } else {
            content.disabled(formState.status == .submitted)
        }
    }
}

internal struct ValidFormButtonEnableBehavior: ViewModifier {
    let onApply: ((Bool, ThomasEnableBehavior) -> Void)?

    @EnvironmentObject var formState: ThomasFormState
    @Environment(\.isVisible) private var isVisible

    @State var isEnabled: Bool?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let onApply = onApply {
            content.airshipOnChangeOf(
                [isValid, isVisible],
                initial: true
            ) { _ in
                if (isVisible) {
                    onApply(!isValid, .formValidation)
                }
            }
        } else {
            content.airshipOnChangeOf(
                [isValid, isVisible],
                initial: true
            ) { _ in
                // We have some disable state flash when going from a page that is invalid,
                // back, then forward back to the invalid page. This small delays
                // prevents the extra enable/disable
                if (isVisible) {
                    DispatchQueue.main.async {
                        isEnabled = isValid
                    }
                }
            }
            .disabled(isEnabled == false)
        }
    }

    var isValid: Bool {
        return switch(formState.validationMode) {
        case .onDemand:
            switch(formState.status) {
            case .error, .valid, .pendingValidation: true
            case .invalid, .validating, .submitted: false
            }
        case .immediate:
            switch(formState.status) {
            case .error, .valid: true
            case .pendingValidation, .invalid, .validating, .submitted: false
            }
        }
    }
}

internal struct PagerNextButtonEnableBehavior: ViewModifier {
    let onApply: ((Bool, ThomasEnableBehavior) -> Void)?

    @EnvironmentObject var pagerState: PagerState

    @ViewBuilder
    func body(content: Content) -> some View {
        if let onApply = onApply {
            content.onReceive(self.pagerState.$pageIndex) { pageIndex in
                onApply(pageIndex < (pagerState.pageStates.count - 1), .pagerNext)
            }
        } else {
            content.disabled(
                pagerState.pageIndex >= (pagerState.pageStates.count - 1)
            )
        }
    }
}

struct PagerPreviousButtonEnableBehavior: ViewModifier {
    let onApply: ((Bool, ThomasEnableBehavior) -> Void)?

    @EnvironmentObject var pagerState: PagerState

    @ViewBuilder
    func body(content: Content) -> some View {
        if let onApply = onApply {
            content.onReceive(self.pagerState.$pageIndex) { pageIndex in
                onApply(pageIndex > 0, .pagerPrevious)
            }
        } else {
            content.disabled(pagerState.pageIndex <= 0)
        }
    }
}

internal struct AggregateEnableBehavior: ViewModifier {
    let behaviors: [ThomasEnableBehavior]
    let onApply: ((Bool) -> Void)

    @State private var enabledBehaviors: [ThomasEnableBehavior: Bool] = [:]
    @State private var enabled: Bool?

    @ViewBuilder
    func body(content: Content) -> some View {
        content.addBehaviorModifiers(behaviors) { behaviorEnabled, behavior in
            enabledBehaviors[behavior] = behaviorEnabled
            let updated = !enabledBehaviors.contains(where: { _, value in
                !value
            })

            if updated != enabled {
                enabled = updated
                onApply(updated)
            }
        }
    }
}

extension View {
    @ViewBuilder
    fileprivate func addBehaviorModifiers(
        _ behaviors: [ThomasEnableBehavior]?,
        onApply: ((Bool, ThomasEnableBehavior) -> Void)? = nil
    ) -> some View {
        if let behaviors = behaviors {
            self.viewModifiers {
                if behaviors.contains(.formValidation) {
                    ValidFormButtonEnableBehavior(onApply: onApply)
                }

                if behaviors.contains(.pagerNext) {
                    PagerNextButtonEnableBehavior(onApply: onApply)
                }

                if behaviors.contains(.pagerPrevious) {
                    PagerPreviousButtonEnableBehavior(onApply: onApply)
                }

                if behaviors.contains(.formSubmission) {
                    FormSubmissionEnableBehavior(onApply: onApply)
                }
            }
        } else {
            self
        }
    }

    @ViewBuilder
    func thomasEnableBehaviors(
        _ behaviors: [ThomasEnableBehavior]?,
        onApply: ((Bool) -> Void)? = nil
    ) -> some View {

        if let behaviors = behaviors {
            if let onApply = onApply {
                self.modifier(
                    AggregateEnableBehavior(
                        behaviors: behaviors,
                        onApply: onApply
                    )
                )
            } else {
                self.addBehaviorModifiers(behaviors)
            }
        } else {
            self
        }
    }
}
