/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

extension View {
    @ViewBuilder
    func constraints(
        _ constraints: ViewConstraints,
        alignment: Alignment? = nil,
        fixedSize: Bool = false
    ) -> some View {
        self.frame(
            idealWidth: constraints.width,
            maxWidth: constraints.width,
            idealHeight: constraints.height,
            maxHeight: constraints.height,
            alignment: alignment ?? .center
        )
        .airshipApplyIf(fixedSize) { view in
            view.fixedSize(
                horizontal: constraints.isHorizontalFixedSize
                    && constraints.width != nil,
                vertical: constraints.isVerticalFixedSize
                    && constraints.height != nil
            )
        }
    }
}
