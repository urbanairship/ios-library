/* Copyright Airship and Contributors */

import Combine
import Foundation
import SwiftUI
@_spi(AirshipInternal) import AirshipBasement


struct FormVisibilityViewModifier: ViewModifier {
    @Environment(\.isVisible) private var isVisible
    @EnvironmentObject fileprivate var formState: ThomasFormState

    @ViewBuilder
    func body(content: Content) -> some View {
        content
            .onAppear {
                if isVisible {
                    formState.markVisible()
                }
            }
            .airshipOnChangeOf(isVisible) { [weak formState] newValue in
                if newValue {
                    formState?.markVisible()
                }
            }
    }
}

struct FormInputEnabledViewModifier: ViewModifier {
    @EnvironmentObject fileprivate var formState: ThomasFormState

    @ViewBuilder
    func body(content: Content) -> some View {
        content.disabled(
            !formState.isFormInputEnabled
        )
    }
}

extension View {
    @ViewBuilder
    @MainActor
    func formElement() -> some View {
        self.viewModifiers {
            FormVisibilityViewModifier()
            FormInputEnabledViewModifier()
        }
    }
}
