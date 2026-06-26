/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Combine
@_spi(AirshipInternal) import AirshipBasement

/// Image Button view.
struct ImageButton : View {
 
    /// Image Button model.
    private let info: ThomasViewInfo.ImageButton

    /// View constraints.
    private let constraints: ViewConstraints
  
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.layoutState) private var layoutState
    @EnvironmentObject private var thomasEnvironment: ThomasEnvironment
    @EnvironmentObject private var thomasState: ThomasState
    @Environment(\.thomasAssociatedLabelResolver) private var associatedLabelResolver

    init(info: ThomasViewInfo.ImageButton, constraints: ViewConstraints) {
        self.info = info
        self.constraints = constraints
    }

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
            outcomes: makeOutcomes(),
            eventHandlers: self.info.commonProperties.eventHandlers,
            tapEffect: self.info.properties.tapEffect
        ) {
            makeInnerButton()
                .constraints(constraints, fixedSize: true)
                .thomasCommon(self.info, scope: [.background])
                .accessible(
                    self.info.accessible,
                    associatedLabel: self.associatedLabel,
                    hideIfDescriptionIsMissing: false
                )
                .background(Color.airshipTappableClear)
        }
        .thomasCommon(self.info, scope: [.enableBehaviors, .visibility])
        .environment(
            \.layoutState,
             layoutState.override(
                buttonState: ButtonState(identifier: self.info.properties.identifier)
             )
        )
        .accessibilityHidden(info.accessible.accessibilityHidden ?? false)
    }
    
    private var resolvedImage: ThomasViewInfo.ImageButton.ButtonImage {
        ThomasPropertyOverride.resolveRequired(
            state: thomasState,
            overrides: info.overrides?.image,
            defaultValue: info.properties.image
        )
    }

    @ViewBuilder
    private func makeInnerButton() -> some View {
        switch resolvedImage {
        case .url(let info):
            ThomasAsyncImage(
                url: info.urlSelectors?.resolve(colorScheme: colorScheme) ?? info.url,
                loadImage: thomasEnvironment.loadImage,
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
    
    private func makeOutcomes() -> [ThomasOutcome] {
        if let outcomes = info.properties.outcomes {
            return outcomes
        }
        
        var result = info.properties.clickBehaviors?.map(\.asOutcome) ?? []
        if let action = info.properties.actions?.asOutcome() {
            result += [action]
        }
        
        return result
    }
}
