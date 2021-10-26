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
        let childConstraints = ViewConstraints(width: self.model.direction == .vertical ? self.constraints.width : nil,
                                               height: self.model.direction == .vertical ? nil :  self.constraints.height)
        
        ScrollView(self.model.direction == .vertical ? .vertical : .horizontal) {
            ViewFactory.createView(model: self.model.view, constraints: childConstraints)
        }
        .background(self.model.background)
        .border(self.model.border)
    }
}
