/* Copyright Airship and Contributors */

import Foundation
import SwiftUI


@available(iOS 13.0.0, tvOS 13.0, *)
struct SubmitFormButtonClickBehavior: ViewModifier {
    @EnvironmentObject var formState: FormState
    @EnvironmentObject var context: ThomasContext

    @ViewBuilder
    func body(content: Content) -> some View {
        content.addTapGesture {
            if let data = formState.data.toDictionary() {
                context.eventHandler.onFormResult(formIdentifier: formState.formIdentifier, formData: data)
            }
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
    @EnvironmentObject var context: ThomasContext

    @ViewBuilder
    func body(content: Content) -> some View {
        content.addTapGesture {
            context.eventHandler.onDismiss(buttonIdentifier: buttonIdentifier)
        }
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
struct CancelButtonClickBehavior: ViewModifier {
    let buttonIdentifier: String
    @EnvironmentObject var context: ThomasContext
    
    @ViewBuilder
    func body(content: Content) -> some View {
        content.addTapGesture {
            context.eventHandler.onCancel(buttonIdentifier: buttonIdentifier)
        }
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
struct ReportButtonModifier: ViewModifier {
    let buttonIdentifier: String
    @EnvironmentObject var context: ThomasContext
    
    @ViewBuilder
    func body(content: Content) -> some View {
        content.addTapGesture {
            context.eventHandler.onButtonTap(buttonIdentifier: buttonIdentifier)
        }
    }
}


@available(iOS 13.0.0, tvOS 13.0, *)
struct RunActionsButtonModifier: ViewModifier {
    let actions: [String : Any]
    
    @EnvironmentObject var context: ThomasContext
    
    @ViewBuilder
    func body(content: Content) -> some View {
        content.addTapGesture {
            context.eventHandler.onRunActions(actions: actions)
        }
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
extension View {
    @ViewBuilder
    func buttonClick(_ buttonIdentifier: String,
                     behaviors: [ButtonClickBehavior]?,
                     actions: [String : Any]? = nil) -> some View {
        
        let behaviors = behaviors ?? []
        let actions = actions ?? [:]

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
        .applyIf(!actions.isEmpty) { view in
            view.modifier(RunActionsButtonModifier(actions: actions))
        }
        .modifier(ReportButtonModifier(buttonIdentifier: buttonIdentifier))
    }
}

