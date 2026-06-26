/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Combine
@_spi(AirshipInternal) import AirshipBasement

struct StackImageButton : View {

    /// Image Button model.
    private let info: ThomasViewInfo.StackImageButton

    /// View constraints.
    private let constraints: ViewConstraints

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.layoutState) private var layoutState
    @EnvironmentObject private var thomasEnvironment: ThomasEnvironment
    @EnvironmentObject private var thomasState: ThomasState
    @Environment(\.thomasAssociatedLabelResolver) private var associatedLabelResolver

    init(info: ThomasViewInfo.StackImageButton, constraints: ViewConstraints) {
        self.info = info
        self.constraints = constraints
    }

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
                if let string = thomasEnvironment.localizedString(key: ref) {
                    return string
                }
            }
        } else if let ref = localized.ref {
            if let string = thomasEnvironment.localizedString(key: ref) {
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
            outcomes: makeOutcomes(),
            eventHandlers: self.info.commonProperties.eventHandlers,
            tapEffect: self.info.properties.tapEffect
        ) {
            StackImageButtonContent(items: resolveItems, constraints: constraints)
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

    private func makeOutcomes() -> [ThomasOutcome] {
        if let outcomes = self.info.properties.outcomes {
            return outcomes
        }
        
        var result = self.info.properties.clickBehaviors?.map(\.asOutcome) ?? []
        if let action = self.info.properties.actions?.asOutcome() {
            result.append(action)
        }
        
        return result
    }
}

/// The button's inner content, extracted into its own concrete `View` type.
///
/// Inlining this `ZStack`/`ForEach`/`switch` directly in `StackImageButton.body`
/// (on top of the `constraints`/`thomasCommon`/`accessible` modifier chain) builds
/// an opaque-type tree large enough to crash the Xcode 27 / Swift 6.4 optimizer
/// under -O + library evolution (non-terminating substOpaqueTypesWithUnderlyingTypes
/// in SILGen). Referencing a named struct keeps `body`'s type tree small while
/// preserving full static typing (and thus view identity / animations), unlike
/// erasing to `AnyView`.
private struct StackImageButtonContent: View {

    let items: [ThomasViewInfo.StackImageButton.Item]
    let constraints: ViewConstraints

    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var thomasEnvironment: ThomasEnvironment

    var body: some View {
        ZStack {
            ForEach(0..<items.count, id: \.self) { index in
                let item = items[index]
                switch(item) {
                case .icon(let item):
                    Icons.icon(info: item.icon, colorScheme: colorScheme)
                case .imageURL(let info):
                    ThomasAsyncImage(
                        url: info.urlSelectors?.resolve(colorScheme: colorScheme) ?? info.url,
                        loadImage: thomasEnvironment.loadImage,
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
