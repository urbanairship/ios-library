/* Copyright Airship and Contributors */

import SwiftUI
import Combine

/**
 * Internal only
 * :nodoc:
 */
struct CustomView: View {
    let model: CustomViewModel

    let constraints: ViewConstraints

    @State private var customView: AnyView?

    @EnvironmentObject
    var thomasEnvironment: ThomasEnvironment

    @Environment(\.layoutState) var layoutState

    var body: some View {
        if let name = model.name {
            AirshipCustomViewManager.shared.makeCustomView(name: name, json: model.json)
                .constraints(constraints)
                .frame(height:model.height)
                .clipped() /// Clip to view frame to ensure we don't overflow when the view has an intrinsic size it's trying to enforce
                .background(
                    color: self.model.backgroundColor,
                    border: self.model.border
                )
                .common(self.model)
        }
    }
}
