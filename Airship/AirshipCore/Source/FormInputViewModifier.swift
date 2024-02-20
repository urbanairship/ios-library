/* Copyright Airship and Contributors */

import Combine
import Foundation
import SwiftUI


struct FormVisibilityViewModifier: ViewModifier {
    @Environment(\.isVisible) private var isVisible
    @EnvironmentObject var formState: FormState

    @ViewBuilder
    func body(content: Content) -> some View {
        content.airshipOnChangeOf( isVisible) { newValue in
            if newValue {
                formState.markVisible()
            }
        }
    }
}

struct FormInputEnabledViewModifier: ViewModifier {
    @EnvironmentObject var formState: FormState

    @ViewBuilder
    func body(content: Content) -> some View {
        content.disabled(!formState.isFormInputEnabled)
    }
}

extension View {
    @ViewBuilder
    @MainActor
    func formElement() -> some View {
        self.modifier(FormVisibilityViewModifier())
            .modifier(FormInputEnabledViewModifier())
    }
}
