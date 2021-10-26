/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// Empty View
@available(iOS 13.0.0, tvOS 13.0, *)
struct EmptyView : View {

    let model: EmptyViewModel

    let constraints: ViewConstraints

    var body: some View {
        Shapes.rectangle(color: self.model.backgroundColor, border: self.model.border)
            .constraints(constraints)
    }
}
