/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
extension View {    
    @ViewBuilder
    func applyIf<Content: View>(_ predicate: () -> Bool, transform: (Self) -> Content) -> some View {
        applyIf(predicate(), transform: transform)
    }
    
    @ViewBuilder
    func applyIf<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if (condition) {
            transform(self)
        } else {
            self
        }
    }

    func addTapGesture(action: @escaping () -> Void) -> some View {
        #if os(tvOS)
        // broken on tvOS for now
        self
        #else
        self.simultaneousGesture(TapGesture().onEnded(action))
        #endif
    }
    
    func viewAccessibility(label: String?) -> some View {
        return self
            .accessibility(label: Text(label ?? ""))
    }
}

