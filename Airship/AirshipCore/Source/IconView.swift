/* Copyright Airship and Contributors */


import SwiftUI

// Icon view that can be used to display icons inside a toggle layout
struct IconView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var thomasState: ThomasState

    let info: ThomasViewInfo.IconView
    let constraints: ViewConstraints

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
            .thomasBackground(
                color: self.info.commonProperties.backgroundColor,
                colorOverrides: self.info.commonOverrides?.backgroundColor,
                border: self.info.commonProperties.border,
                borderOverrides: self.info.commonOverrides?.border
            )
            .background(Color.airshipTappableClear)
            .thomasEnableBehaviors(self.info.commonProperties.enabled)
            .thomasVisibility(self.info.commonProperties.visibility)
    }
}
