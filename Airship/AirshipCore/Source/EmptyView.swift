/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// Empty View

struct AirshipEmptyView: View {

    let model: EmptyViewModel
    let constraints: ViewConstraints

    var body: some View {
        Color.clear
            .constraints(constraints)
            .background(
                color: self.model.backgroundColor,
                border: self.model.border
            )
            .common(self.model)
    }
}
