/* Copyright Airship and Contributors */


import Foundation
import SwiftUI

extension View {
    @ViewBuilder
    func applyTextTheme(_ textTheme: InAppMessageTheme.Text) -> some View {
        self.padding(textTheme.padding)
            .lineSpacing(textTheme.lineSpacing)
            .kerning(textTheme.letterSpacing)
        
    }
}
