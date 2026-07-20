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
        // Report the input's frame (innermost, so it is a descendant of the disabled
        // modifier below and skips reporting when the input is disabled) so an enclosing
        // pager can suppress region tap gestures that land on it. Covers toggle, checkbox,
        // radio, score, and text input.
        self.reportPagerGestureExclusion()
            .viewModifiers {
                FormVisibilityViewModifier()
                FormInputEnabledViewModifier()
            }
    }
}
