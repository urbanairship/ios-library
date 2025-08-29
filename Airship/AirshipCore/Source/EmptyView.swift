/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// Empty View

struct AirshipEmptyView: View {

    let info: ThomasViewInfo.EmptyView
    let constraints: ViewConstraints

    var body: some View {
        Color.clear
            .constraints(constraints)
            .thomasCommon(self.info)
    }
}
