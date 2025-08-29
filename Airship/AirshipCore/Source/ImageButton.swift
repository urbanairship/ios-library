/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Combine

/// Image Button view.
struct ImageButton : View {
 
    /// Image Button model.
    let info: ThomasViewInfo.ImageButton

    /// View constraints.
    let constraints: ViewConstraints
  
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.layoutState) var layoutState
    @EnvironmentObject var thomasEnvironment: ThomasEnvironment
    @EnvironmentObject var thomasState: ThomasState
    @Environment(\.thomasAssociatedLabelResolver) var associatedLabelResolver

    private var associatedLabel: String? {
        associatedLabelResolver?.labelFor(
            identifier: info.properties.identifier,
            viewType: .imageButton,
            thomasState: thomasState
        )
    }

    @ViewBuilder
    var body: some View {
        AirshipButton(
            identifier: self.info.properties.identifier,
            reportingMetadata: self.info.properties.reportingMetadata,
            description: self.info.accessible.resolveContentDescription,
            clickBehaviors: self.info.properties.clickBehaviors,
            eventHandlers: self.info.commonProperties.eventHandlers,
            actions: self.info.properties.actions,
            tapEffect: self.info.properties.tapEffect
        ) {
            makeInnerButton()
                .constraints(constraints, fixedSize: true)
                .thomasBackground(
                    color: self.info.commonProperties.backgroundColor,
                    colorOverrides: self.info.commonOverrides?.backgroundColor,
                    border: self.info.commonProperties.border,
                    borderOverrides: self.info.commonOverrides?.border
                )
                .accessible(
                    self.info.accessible,
                    associatedLabel: self.associatedLabel,
                    hideIfDescriptionIsMissing: false
                )
                .background(Color.airshipTappableClear)
        }
        .thomasEnableBehaviors(self.info.commonProperties.enabled)
        .thomasVisibility(self.info.commonProperties.visibility)
        .environment(
            \.layoutState,
             layoutState.override(
                buttonState: ButtonState(identifier: self.info.properties.identifier)
             )
        )
        .accessibilityHidden(info.accessible.accessibilityHidden ?? false)
    }
    
    @ViewBuilder
    private func makeInnerButton() -> some View {
        switch(self.info.properties.image) {
        case .url(let info):
            ThomasAsyncImage(
                url: info.url,
                imageLoader: thomasEnvironment.imageLoader,
                image: { image, imageSize in
                    image.fitMedia(
                        mediaFit: info.mediaFit ?? .centerInside,
                        cropPosition: info.cropPosition,
                        constraints: constraints,
                        imageSize: imageSize
                    )
                },
                placeholder: {
                    AirshipProgressView()
                }
            )
        case .icon(let info):
            Icons.icon(info: info, colorScheme: colorScheme)
        }
    }
}
