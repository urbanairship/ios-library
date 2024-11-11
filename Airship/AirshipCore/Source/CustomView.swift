/* Copyright Airship and Contributors */

import SwiftUI
import Combine

/**
 * Internal only
 * :nodoc:
 */
struct CustomView: View {
    let info: ThomasViewInfo.CustomView
    let constraints: ViewConstraints

    @EnvironmentObject
    var thomasEnvironment: ThomasEnvironment

    @Environment(\.layoutState) var layoutState

    var body: some View {
        AirshipCustomViewManager.shared.makeCustomView(
            name: self.info.properties.name,
            json: self.info.properties.json
        )
        .constraints(constraints)
        .clipped() /// Clip to view frame to ensure we don't overflow when the view has an intrinsic size it's trying to enforce
        .thomasCommon(self.info)
    }
}
