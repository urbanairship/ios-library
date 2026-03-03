/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

extension Binding where Value == String {
    func preventWhiteSpace() -> Binding<String> {
        return Binding<String>(
            get: { self.wrappedValue },
            set: {
                self.wrappedValue = $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
        )
    }
}

extension View {
    @ViewBuilder
    func freeInput() -> some View {
#if os(macOS)
        self.disableAutocorrection(true)
#else
        
        self.textInputAutocapitalization(.never)
            .disableAutocorrection(true)
#endif
    }
}
