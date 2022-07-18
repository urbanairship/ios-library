/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
extension View {
    @ViewBuilder
    func ignoreKeyboardSafeArea() -> some View {
        if #available(iOS 14.0, tvOS 14.0, *) {
            self.ignoresSafeArea(.keyboard)
        } else {
            self
        }
    }
    
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

    @ViewBuilder
    func accessible(_ accessible: Accessible?) -> some View {
        if let label = accessible?.contentDescription {
            self.accessibility(label: Text(label))
        } else {
            self
        }
    }


    @ViewBuilder
    func common<Content: BaseModel>(_ model: Content,
                formInputID: String? = nil) -> some View {
        self.eventHandlers(model.eventHandlers, formInputID: formInputID)
            .enableBehaviors(model.enableBehaviors)
            .visibility(model.visibility)
    }
}

