/* Copyright Airship and Contributors */


import Foundation
import SwiftUI

extension View {
    @ViewBuilder
    func applyTextTheme(_ textTheme: InAppMessageTheme.Text) -> some View {
        if #available(iOS 16.0, *) {
            self
                .padding(textTheme.padding)
                .lineSpacing(textTheme.lineSpacing)
                .kerning(textTheme.letterSpacing)
        } else {
            self
                .padding(textTheme.padding)
                .lineSpacing(textTheme.lineSpacing)
            /// TODO add a pre-16.0 version of kerning/letter spacing and manually test
        }
    }
}
