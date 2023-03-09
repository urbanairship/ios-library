/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// Button view.
@available(iOS 13.0.0, tvOS 13.0, *)
struct AirshipButton<Label> : View  where Label : View {

    @EnvironmentObject private var formState: FormState
    @EnvironmentObject private var pagerState: PagerState
    @EnvironmentObject private var viewState: ViewState
    @EnvironmentObject private var thomasEnvironment: ThomasEnvironment
    @Environment(\.layoutState) private var layoutState

    let identifier: String
    let description: String
    let clickBehaviors:[ButtonClickBehavior]?
    let actions: ActionsPayload?
    let label: () -> Label


    var body: some View {

        Button(
            action: {
                doButtonActions()
            },
            label: self.label
        )
    }

    private func doButtonActions() {
        thomasEnvironment.buttonTapped(
            buttonIdentifier: self.identifier,
            layoutState: layoutState
        )

        clickBehaviors?.sorted { first, second in
            first.sortOrder < second.sortOrder
        }.forEach { behavior in
            switch(behavior) {
            case .dismiss:
                thomasEnvironment.dismiss(
                    buttonIdentifier: self.identifier,
                    buttonDescription: self.description,
                    cancel: false,
                    layoutState: layoutState
                )

            case .cancel:
                  thomasEnvironment.dismiss(
                    buttonIdentifier: self.identifier,
                    buttonDescription: self.description,
                    cancel: true,
                    layoutState: layoutState
                  )

            case .pagerNext:
                withAnimation {
                    pagerState.pageIndex = min(pagerState.pageIndex + 1, pagerState.pages.count - 1)
                }

            case .pagerPrevious:
                withAnimation {
                    pagerState.pageIndex = max(pagerState.pageIndex - 1, 0)
                }

            case .formSubmit:
                let formState = formState.topFormState
                thomasEnvironment.submitForm(formState, layoutState: layoutState)
                formState.markSubmitted()
            }
        }

        if let actions = actions {
            thomasEnvironment.runActions(actions, layoutState: layoutState)
        }
    }
}

fileprivate extension ButtonClickBehavior {
    var sortOrder: Int {
        switch self {
        case .dismiss:
            return 2
        case .cancel:
            return 2
        case .pagerNext:
            return 1
        case .pagerPrevious:
            return 1
        case .formSubmit:
            return 0
        }
    }
}
