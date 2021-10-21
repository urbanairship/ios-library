/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// Scroll view layout
@available(iOS 13.0.0, tvOS 13.0, *)
struct ScrollLayout : View {

    /// ScrollLayout model.
    let model: ScrollLayoutModel
    
    /// View constriants.
    let constraints: ViewConstraints
    
    var body: some View {
        ScrollView {
            ViewFactory.createView(model: self.model.view, constraints: constraints)
        }
        .background(self.model.background)
        .border(self.model.border)
    }
}
