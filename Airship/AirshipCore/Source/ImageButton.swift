/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Combine

/// Image Button view.
struct ImageButton : View {
 
    /// Image Button model.
    let model: ImageButtonModel
  
    /// View constraints.
    let constraints: ViewConstraints
  
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.layoutState) var layoutState
    @EnvironmentObject var thomasEnvironment: ThomasEnvironment

    @ViewBuilder
    var body: some View {
        AirshipButton(
            identifier: self.model.identifier,
            reportingMetadata: self.model.reportingMetadata,
            description: self.model.contentDescription ?? self.model.localizedContentDescription?.localized,
            clickBehaviors: self.model.clickBehaviors,
            eventHandlers: self.model.eventHandlers,
            actions: self.model.actions,
            tapEffect: self.model.tapEffect
        ) {
            makeInnerButton()
                .constraints(constraints, fixedSize: true)
                .background(
                    color: self.model.backgroundColor,
                    border: self.model.border
                )
                .accessible(self.model)
                .background(Color.airshipTappableClear)
        }
        .commonButton(self.model)
        .environment(
            \.layoutState,
             layoutState.override(
                buttonState: ButtonState(identifier: self.model.identifier)
             )
        )
        .accessibilityHidden(model.accessibilityHidden ?? false)

    }
    
    @ViewBuilder
    private func makeInnerButton() -> some View {
        switch(model.image) {
        case .url(let model):
            ThomasAsyncImage(
                url: model.url,
                imageLoader: thomasEnvironment.imageLoader,
                image: { image, imageSize in
                    image.fitMedia(
                        mediaFit: model.mediaFit ?? .centerInside,
                        cropPosition: model.cropPosition,
                        constraints: constraints,
                        imageSize: imageSize
                    )
                },
                placeholder: {
                    AirshipProgressView()
                }
            )
        case .icon(let model):
            Icons.icon(model: model, colorScheme: colorScheme)
        }
    }
}
