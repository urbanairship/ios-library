/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Combine

struct StackImageButton : View {

    /// Image Button model.
    let info: ThomasViewInfo.StackImageButton

    /// View constraints.
    let constraints: ViewConstraints

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.layoutState) var layoutState
    @EnvironmentObject var thomasEnvironment: ThomasEnvironment
    @EnvironmentObject var thomasState: ThomasState
    @Environment(\.thomasAssociatedLabelResolver) var associatedLabelResolver

    private var resolveItems: [ThomasViewInfo.StackImageButton.Item] {
        ThomasPropertyOverride.resolveRequired(
            state: thomasState,
            overrides: info.overrides?.items,
            defaultValue: info.properties.items
        )
    }

    private var resolvedLocalizedContentDescription: ThomasAccessibleInfo.Localized? {
        ThomasPropertyOverride.resolveOptional(
            state: thomasState,
            overrides: info.overrides?.localizedContentDescription,
            defaultValue: info.accessible.localizedContentDescription
        )
    }

    private var resolvedContentDescription: String? {
        if let contentDescription = ThomasPropertyOverride.resolveOptional(
            state: thomasState,
            overrides: info.overrides?.contentDescription,
            defaultValue: info.accessible.contentDescription
        ) {
            return contentDescription
        }

        guard let localized = resolvedLocalizedContentDescription else {
            return nil
        }

        if let refs = localized.refs {
            for ref in refs {
                if let string = AirshipResources.localizedString(key: ref) {
                    return string
                }
            }
        } else if let ref = localized.ref {
            if let string = AirshipResources.localizedString(key: ref) {
                return string
            }
        }

        return localized.fallback
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
            description: self.resolvedContentDescription,
            clickBehaviors: self.info.properties.clickBehaviors,
            eventHandlers: self.info.commonProperties.eventHandlers,
            actions: self.info.properties.actions,
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

    @ViewBuilder
    private func makeInnerButton() -> some View {
        let items = resolveItems
        ZStack {
            ForEach(0..<items.count, id: \.self) { index in
                let item = items[index]
                switch(item) {
                case .icon(let item):
                    Icons.icon(info: item.icon, colorScheme: colorScheme)
                case .imageURL(let info):
                    ThomasAsyncImage(
                        url: info.url,
                        imageLoader: thomasEnvironment.imageLoader,
                        image: { image, imageSize in
                            image.fitMedia(
                                mediaFit: info.mediaFit,
                                cropPosition: info.cropPosition,
                                constraints: constraints,
                                imageSize: imageSize
                            )
                        },
                        placeholder: {
                            AirshipProgressView()
                        }
                    )
                case .shape(let info):
                    Shapes.shape(
                        info: info.shape, constraints: constraints, colorScheme: colorScheme
                    )
                }
            }
        }
    }
}
