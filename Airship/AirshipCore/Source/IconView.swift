/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

// Icon view that can be used to display icons inside a toggle layout
struct IconView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var thomasState: ThomasState

    private let info: ThomasViewInfo.IconView
    private let constraints: ViewConstraints

    init(info: ThomasViewInfo.IconView, constraints: ViewConstraints) {
        self.info = info
        self.constraints = constraints
    }

    private var resolvedIcon: ThomasIconInfo {
        return ThomasPropertyOverride.resolveRequired(
            state: self.thomasState,
            overrides: self.info.overrides?.icon,
            defaultValue: self.info.properties.icon
        )
    }

    var body: some View {
        Icons.icon(info: resolvedIcon, colorScheme: colorScheme)
            .constraints(constraints, fixedSize: true)
            .background(Color.airshipTappableClear)
            .thomasCommon(self.info)
    }
}
