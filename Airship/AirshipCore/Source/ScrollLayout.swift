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
        let width = self.model.direction == .vertical ? self.constraints.contentWidth : nil
        let height = self.model.direction == .vertical ? nil : self.constraints.contentHeight
        
        let childConstraints = ViewConstraints(contentWidth: width,
                                               contentHeight: height,
                                               frameWidth: width,
                                               frameHeight: height)
        
        ScrollView(self.model.direction == .vertical ? .vertical : .horizontal) {
            ViewFactory.createView(model: self.model.view, constraints: childConstraints)
        }
        .background(self.model.backgroundColor)
        .border(self.model.border)
        .constraints(self.constraints)
    }
}
