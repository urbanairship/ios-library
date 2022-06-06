/* Copyright Airship and Contributors */

import Foundation
import SwiftUI


@available(iOS 13.0.0, tvOS 13.0, *)
struct SubmitFormButtonClickBehavior: ViewModifier {
    @EnvironmentObject var formState: FormState
    @EnvironmentObject var thomasEnvironment: ThomasEnvironment
    @Environment(\.layoutState) var layoutState

    @ViewBuilder
    func body(content: Content) -> some View {
        content.addTapGesture {
            thomasEnvironment.submitForm(formState, layoutState: layoutState)
            formState.markSubmitted()
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
                pagerState.pageIndex = min(pagerState.pageIndex + 1, pagerState.pages.count - 1)
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
                pagerState.pageIndex = max(pagerState.pageIndex - 1, 0)
            }
        }
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
struct DismissButtonClickBehavior: ViewModifier {
    let buttonIdentifier: String
    let buttonDescription: String

    @EnvironmentObject var thomasEnvironment: ThomasEnvironment
    @Environment(\.layoutState) var layoutState

    @ViewBuilder
    func body(content: Content) -> some View {
        content.addTapGesture {
            thomasEnvironment.dismiss(buttonIdentifier: buttonIdentifier,
                                      buttonDescription: buttonDescription,
                                      cancel: false,
                                      layoutState: layoutState)
        }
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
struct CancelButtonClickBehavior: ViewModifier {
    let buttonIdentifier: String
    let buttonDescription: String
    @EnvironmentObject var thomasEnvironment: ThomasEnvironment
    @Environment(\.layoutState) var layoutState

    @ViewBuilder
    func body(content: Content) -> some View {
        content.addTapGesture {
            thomasEnvironment.dismiss(buttonIdentifier: buttonIdentifier,
                                      buttonDescription: buttonDescription,
                                      cancel: true,
                                      layoutState: layoutState)
        }
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
struct ReportButtonModifier: ViewModifier {
    let buttonIdentifier: String
    
    @EnvironmentObject var thomasEnvironment: ThomasEnvironment
    @Environment(\.layoutState) var layoutState

    @ViewBuilder
    func body(content: Content) -> some View {
        content.addTapGesture {
            thomasEnvironment.buttonTapped(buttonIdentifier: buttonIdentifier, layoutState: layoutState)
        }
    }
}


@available(iOS 13.0.0, tvOS 13.0, *)
struct RunActionsButtonModifier: ViewModifier {
    let actions: ActionsPayload?
    
    @EnvironmentObject var thomasEnvironment: ThomasEnvironment
    @Environment(\.layoutState) var layoutState

    @ViewBuilder
    func body(content: Content) -> some View {
        content.addTapGesture {
            thomasEnvironment.runActions(actions, layoutState: layoutState)
        }
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
extension View {
    @ViewBuilder
    func buttonClick(_ buttonIdentifier: String,
                     buttonDescription: String,
                     behaviors: [ButtonClickBehavior]?,
                     actions: ActionsPayload? = nil) -> some View {
        
        let behaviors = behaviors ?? []

        self.applyIf(actions != nil) { view in
            view.modifier(RunActionsButtonModifier(actions: actions))
        }
        .applyIf(behaviors.contains(.dismiss)) { view in
            view.modifier(DismissButtonClickBehavior(buttonIdentifier: buttonIdentifier, buttonDescription: buttonDescription))
        }
        .applyIf(behaviors.contains(.cancel)) { view in
            view.modifier(CancelButtonClickBehavior(buttonIdentifier: buttonIdentifier, buttonDescription: buttonDescription))
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
        .modifier(ReportButtonModifier(buttonIdentifier: buttonIdentifier))
    }
}

