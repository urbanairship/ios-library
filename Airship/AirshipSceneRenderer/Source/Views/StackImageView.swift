/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
@_spi(AirshipInternal) import AirshipBasement

/// Non-interactive counterpart to `StackImageButton`. Renders a stack of
/// icon/shape/image items for decorative elements, such as a banner nub.
struct StackImageView: View {

    /// Stack image view model.
    private let info: ThomasViewInfo.StackImageView

    /// View constraints.
    private let constraints: ViewConstraints

    init(info: ThomasViewInfo.StackImageView, constraints: ViewConstraints) {
        self.info = info
        self.constraints = constraints
    }

    var body: some View {
        StackImageItemsView(items: self.info.properties.items, constraints: constraints)
            .constraints(constraints, fixedSize: true)
            .thomasCommon(self.info)
            .accessible(
                self.info.accessible,
                associatedLabel: nil,
                hideIfDescriptionIsMissing: true
            )
    }
}
