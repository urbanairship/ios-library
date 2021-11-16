/* Copyright Airship and Contributors */

import SwiftUI

// MARK: - Modal modifier

@available(iOS 13.0.0, tvOS 13.0, *)
struct ModalView: View {

    let model: ModalPresentationModel
    let constraints: ViewConstraints
    let rootViewModel: ViewModel
    
    @EnvironmentObject private var context: ThomasContext
    @EnvironmentObject private var orientationState: OrientationState

    #if !os(tvOS)
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    
    var body: some View {
        let placement = resolvePlacement()
        let alignment = Alignment(horizontal: placement.position?.horizontal.toAlignment() ?? .center,
                                  vertical: placement.position?.vertical.toAlignment() ?? .center)
        
        let contentConstraints =  ViewConstraints.calculateChildConstraints(childSize: placement.size,
                                                                            childMargins: placement.margin,
                                                                            parentConstraints: constraints)
        VStack {
            ViewFactory.createView(model: rootViewModel, constraints: contentConstraints)
                .margin(placement.margin)
        }
        .constraints(constraints, alignment: alignment)
        .background(
            Rectangle()
                .foreground(placement.shade)
                .applyIf(self.model.dismissOnTouchOutside == true) { view in
                    // Add tap gesture outside of view to dismiss
                    view.addTapGesture {
                        context.delegate.onDismiss(buttonIdentifier: nil, cancel: false)
                    }
                }
        )
    }
    
    private func resolvePlacement() ->  ModalPlacement {
        for placementSelector in self.model.placementSelectors ?? [] {
            if (placementSelector.windowSize != nil && placementSelector.windowSize != resolveWindowSize()) {
                continue
            }
            
            if (placementSelector.orientation != nil && placementSelector.orientation != orientationState.orientation) {
                continue
            }
            
            // its a match!
            return placementSelector.placement
        }
        
        return self.model.defaultPlacement
    }
    
    /// Uses the vertical and horizontal class size to determine small, medium, large window size:
    /// - large: regular x regular = large
    /// - medium: regular x compact or compact x regular
    /// - small: compact x compact
    private func resolveWindowSize() -> WindowSize {
        #if os(tvOS)
        return .large
        #else
        switch(verticalSizeClass, horizontalSizeClass) {
        case (.regular, .regular):
            return .large
        case (.compact, .compact):
            return .small
        default:
            return .medium
        }
        #endif
    }
}
