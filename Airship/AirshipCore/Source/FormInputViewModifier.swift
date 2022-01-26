/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Combine

@available(iOS 13.0.0, tvOS 13.0, *)
struct FormInputViewModifier: ViewModifier {
    @Environment(\.isVisible) private var isVisible
    @EnvironmentObject var formState: FormState

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 14.0, tvOS 14.0, *) {
            content.onChange(of: isVisible) { newValue in
                if (newValue) {
                    formState.markVisible()
                }
            }
        } else {
            content
                .onAppear()
                .onReceive(Just(isVisible)) { newValue in
                if (newValue) {
                    formState.markVisible()
                }
            }
        }
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
extension View {
    @ViewBuilder
    func formInput() -> some View  {
        self.modifier(FormInputViewModifier())
    }
}

