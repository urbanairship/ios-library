/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// Empty View

struct EmptyView: View {

    let model: EmptyViewModel
    let constraints: ViewConstraints

    var body: some View {
        Color.clear
            .constraints(constraints)
            .background(self.model.backgroundColor)
            .border(self.model.border)
            .common(self.model)
    }
}
