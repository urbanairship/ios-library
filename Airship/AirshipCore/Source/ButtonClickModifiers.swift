/* Copyright Airship and Contributors */

import Foundation
import SwiftUI


@available(iOS 13.0.0, tvOS 13.0, *)
struct SubmitFormButtonClickBehavior: ViewModifier {
    @EnvironmentObject var formState: FormState
    @EnvironmentObject var thomasEnvironment: ThomasEnvironment
    @Environment(\.reportingContext) var reportingContext

    @ViewBuilder
    func body(content: Content) -> some View {
        content.addTapGesture {
            thomasEnvironment.submitForm(formState, reportingContext: reportingContext)
        }
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
struct PagerNextPageButtonClickBehavior: ViewModifier {
    @EnvironmentObject var pagerState: PagerState
    
    @ViewBuilder
    func body(content: Content) -> some View {
        content.addTapGesture {
            withAnimation {
                pagerState.index = min(pagerState.index + 1, pagerState.pages - 1)
            }
        }
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
struct PagerPreviousPageButtonClickBehavior: ViewModifier {
    @EnvironmentObject var pagerState: PagerState
    
    @ViewBuilder
    func body(content: Content) -> some View {
        content.addTapGesture {
            withAnimation {
                pagerState.index = max(pagerState.index - 1, 0)
            }
        }
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
struct DismissButtonClickBehavior: ViewModifier {
    let buttonIdentifier: String
    @EnvironmentObject var thomasEnvironment: ThomasEnvironment
    @Environment(\.reportingContext) var reportingContext

    @ViewBuilder
    func body(content: Content) -> some View {
        content.addTapGesture {
            thomasEnvironment.dismiss(reason: .button(buttonIdentifier, false), reportingContext: reportingContext)
        }
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
struct CancelButtonClickBehavior: ViewModifier {
    let buttonIdentifier: String
    @EnvironmentObject var thomasEnvironment: ThomasEnvironment
    @Environment(\.reportingContext) var reportingContext

    @ViewBuilder
    func body(content: Content) -> some View {
        content.addTapGesture {
            thomasEnvironment.dismiss(reason: .button(buttonIdentifier, true), reportingContext: reportingContext)
        }
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
struct ReportButtonModifier: ViewModifier {
    let buttonIdentifier: String
    @EnvironmentObject var thomasEnvironment: ThomasEnvironment
    @Environment(\.reportingContext) var reportingContext

    @ViewBuilder
    func body(content: Content) -> some View {
        content.addTapGesture {
            thomasEnvironment.buttonTapped(buttonIdentifier: buttonIdentifier, reportingContext: reportingContext)
        }
    }
}


@available(iOS 13.0.0, tvOS 13.0, *)
struct RunActionsButtonModifier: ViewModifier {
    let actions: ActionsPayload?
    
    @EnvironmentObject var thomasEnvironment: ThomasEnvironment

    @ViewBuilder
    func body(content: Content) -> some View {
        content.addTapGesture {
            thomasEnvironment.actionRunner.run(actions?.value ?? [:])
        }
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
extension View {
    @ViewBuilder
    func buttonClick(_ buttonIdentifier: String,
                     behaviors: [ButtonClickBehavior]?,
                     actions: ActionsPayload? = nil) -> some View {
        
        let behaviors = behaviors ?? []

        self.applyIf(behaviors.contains(.dismiss)) { view in
            view.modifier(DismissButtonClickBehavior(buttonIdentifier: buttonIdentifier))
        }
        .applyIf(behaviors.contains(.cancel)) { view in
            view.modifier(CancelButtonClickBehavior(buttonIdentifier: buttonIdentifier))
        }
        .applyIf(behaviors.contains(.formSubmit)) { view in
            view.modifier(SubmitFormButtonClickBehavior())
        }
        .applyIf(behaviors.contains(.pagerNext)) { view in
            view.modifier(PagerNextPageButtonClickBehavior())
        }
        .applyIf(behaviors.contains(.pagerPrevious)) { view in
            view.modifier(PagerPreviousPageButtonClickBehavior())
        }
        .applyIf(actions != nil) { view in
            view.modifier(RunActionsButtonModifier(actions: actions))
        }
        .modifier(ReportButtonModifier(buttonIdentifier: buttonIdentifier))
    }
}

