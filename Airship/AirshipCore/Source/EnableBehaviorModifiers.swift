/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Combine

@available(iOS 13.0.0, tvOS 13.0, *)
internal struct FormSubmissionEnableBehavior: ViewModifier {
    let onApply: ((Bool, EnableBehavior) -> Void)?

    @EnvironmentObject var formState: FormState

    @ViewBuilder
    func body(content: Content) -> some View {
        if let onApply = onApply {
            content.onReceive(self.formState.$isSubmitted) { value in
                onApply(!value, .formSubmission)
            }
        } else {
            content.disabled(formState.isSubmitted)
        }
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
internal struct ValidFormButtonEnableBehavior: ViewModifier {
    let onApply: ((Bool, EnableBehavior) -> Void)?

    @EnvironmentObject var formState: FormState

    @ViewBuilder
    func body(content: Content) -> some View {
        if let onApply = onApply {
            content.onReceive(self.formState.$data) { data in
                onApply(data.isValid, .formValidation)
            }
        } else {
            content.disabled(!formState.data.isValid)
        }
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
internal struct PagerNextButtonEnableBehavior: ViewModifier {
    let onApply: ((Bool, EnableBehavior) -> Void)?

    @EnvironmentObject var pagerState: PagerState

    @ViewBuilder
    func body(content: Content) -> some View {
        if let onApply = onApply {
            content.onReceive(self.pagerState.$pageIndex) { pageIndex in
                onApply(pageIndex < (pagerState.pages.count - 1), .pagerNext)
            }
        } else {
            content.disabled(pagerState.pageIndex >= (pagerState.pages.count - 1))
        }
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
struct PagerPreviousButtonEnableBehavior: ViewModifier {
    let onApply: ((Bool, EnableBehavior) -> Void)?

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

@available(iOS 13.0.0, tvOS 13.0, *)
internal struct AggregateEnableBehavior: ViewModifier {
    let behaviors: [EnableBehavior]
    let onApply: ((Bool) -> Void)

    @State private var enabledBehaviors: [EnableBehavior: Bool] = [:]
    @State private var enabled: Bool?

    @ViewBuilder
    func body(content: Content) -> some View {
        content.addBehaviorModifiers(behaviors) { behaviorEnabled, behavior in
            enabledBehaviors[behavior] = behaviorEnabled
            let updated = !enabledBehaviors.contains(where: { _, value in
                !value
            })

            if (updated != enabled) {
                enabled = updated
                onApply(updated)
            }
        }
    }
}


@available(iOS 13.0.0, tvOS 13.0, *)
extension View {

    @ViewBuilder
    fileprivate func addBehaviorModifiers(_ behaviors: [EnableBehavior]?,
                                       onApply: ((Bool, EnableBehavior) -> Void)? = nil) -> some View {
        if let behaviors = behaviors {
            self.applyIf(behaviors.contains(.formValidation)) { view in
                view.modifier(ValidFormButtonEnableBehavior(onApply: onApply))
            }
            .applyIf(behaviors.contains(.pagerNext)) { view in
                view.modifier(PagerNextButtonEnableBehavior(onApply: onApply))
            }
            .applyIf(behaviors.contains(.pagerPrevious)) { view in
                view.modifier(PagerPreviousButtonEnableBehavior(onApply: onApply))
            }
            .applyIf(behaviors.contains(.formSubmission)) { view in
                view.modifier(FormSubmissionEnableBehavior(onApply: onApply))
            }
        } else {
            self
        }
    }

    @ViewBuilder
    func enableBehaviors(_ behaviors: [EnableBehavior]?,
                         onApply: ((Bool) -> Void)? = nil) -> some View {

        if let behaviors = behaviors {
            if let onApply = onApply {
                self.modifier(AggregateEnableBehavior(behaviors: behaviors, onApply: onApply))
            } else {
                self.addBehaviorModifiers(behaviors)
            }
        } else {
            self
        }
    }
}

