/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

#if !os(tvOS)
fileprivate struct TouchViewModifier: ViewModifier {
    @GestureState var isPressed: Bool = false
    let onChange: (Bool) -> Void

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                TapGesture()
            )
            .gesture(
                LongPressGesture(minimumDuration: 0.1)
                    .sequenced(before: LongPressGesture(minimumDuration: .infinity))
                    .updating($isPressed) { value, state, transaction in
                        switch value {
                            case .second(true, nil):
                                state = true
                            default: break
                        }
                    }
            )
        .airshipOnChangeOf(self.isPressed) { value in
            onChange(value)
        }
    }
}

extension View {
    func onTouch(onChange: @escaping (Bool) -> Void) -> some View {
        self.modifier(TouchViewModifier(onChange: onChange))
    }
}
#endif
