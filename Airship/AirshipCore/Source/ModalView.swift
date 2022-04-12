/* Copyright Airship and Contributors */

import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct ModalView: View {
    
    static let keyboardPadding = 1.0
    @Environment(\.colorScheme) var colorScheme

    let presentation: ModalPresentationModel
    let layout: Layout
    @ObservedObject var thomasEnvironment: ThomasEnvironment
    @ObservedObject private var keyboardResponder = KeyboardResponder()
    let viewControllerOptions: ThomasViewControllerOptions

    @State private var contentSize: (ViewConstraints, CGSize)? = nil

    var body: some View {
        GeometryReader { metrics in
            RootView(thomasEnvironment: thomasEnvironment, layout: layout) { orientation, windowSize in
                let placement = resolvePlacement(orientation: orientation, windowSize: windowSize)
                createModal(placement: placement, metrics:metrics)
            }
        }
        .animation(.easeOut(duration: 0.16))
        .ignoreKeyboardSafeArea()
    }


    private func calculateKeyboardHeight(metrics: GeometryProxy) -> Double {
        guard self.keyboardResponder.keyboardHeight > 0 else { return 0.0 }
        return self.keyboardResponder.keyboardHeight - metrics.safeAreaInsets.bottom + ModalView.keyboardPadding
    }
    
    private func calculateKeyboardOverlap(placement: ModalPlacement,
                                          keyboardHeight: Double,
                                          containerHeight: Double,
                                          contentHeight: Double) -> Double {
        
        guard keyboardHeight > 0 else { return 0.0 }
        guard containerHeight > 0, contentHeight > 0 else { return keyboardHeight }
        
        switch (placement.position?.vertical ?? .center) {
        case .center:
            return max(0, keyboardHeight - ((containerHeight - contentHeight) / 2.0))
        case .bottom:
            return keyboardHeight
        case .top:
            return max(0, keyboardHeight - containerHeight + contentHeight)
        }
    }
  
    private func createModal(placement: ModalPlacement, metrics: GeometryProxy) -> some View {
        let ignoreSafeArea = placement.ignoreSafeArea == true

        var alignment = Alignment(horizontal: placement.position?.horizontal.toAlignment() ?? .center,
                                  vertical: placement.position?.vertical.toAlignment() ?? .center)

        let windowConstraints = ViewConstraints.containerConstraints(metrics.size,
                                                               safeAreaInsets: metrics.safeAreaInsets,
                                                               ignoreSafeArea: ignoreSafeArea)

        var contentSize: CGSize?
        if (windowConstraints == self.contentSize?.0) {
            contentSize = self.contentSize?.1
        }

        var contentConstraints = windowConstraints.calculateChild(placement.size,
                                                                  contentSize: contentSize,
                                                                  margin: placement.margin,
                                                                  ignoreSafeArea: placement.ignoreSafeArea)

        let windowHeight = windowConstraints.height ?? 0
        let contentHeight = contentConstraints.height ?? 0
        let keyboardHeight = calculateKeyboardHeight(metrics: metrics)
        var keyboardOffset = calculateKeyboardOverlap(placement: placement,
                                                      keyboardHeight: keyboardHeight,
                                                      containerHeight: windowHeight,
                                                      contentHeight: contentHeight)

        // If the keyboard will push the content outside the screen,
        // resize it and position it at the top
        if ((keyboardHeight + contentHeight) >= windowHeight) {
            alignment = Alignment(horizontal: alignment.horizontal, vertical: .top)
            keyboardOffset = 0
            contentConstraints = ViewConstraints(width: contentConstraints.width,
                                                 height: windowHeight - keyboardHeight,
                                                 safeAreaInsets: contentConstraints.safeAreaInsets)
        }


        return VStack {
            ViewFactory.createView(model: self.layout.view,
                                   constraints: contentConstraints)
            .margin(placement.margin)
            .background(
                GeometryReader(content: { contentMetrics -> Color in
                    DispatchQueue.main.async {
                        self.contentSize = (windowConstraints, contentMetrics.size)
                    }
                    return Color.clear
                })
            )
            .offset(y: -keyboardOffset)
        }
        .opacity(contentSize == nil ? 0 : 1)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        .background(modalBackground(placement))
        .applyIf(ignoreSafeArea) { $0.edgesIgnoringSafeArea(.all) }
    }

    
    @ViewBuilder
    private func modalBackground(_ placement: ModalPlacement) -> some View {
        if case let .percent(height) = placement.size.height, height >= 1.0,
           case let .percent(value) = placement.size.width, value >= 1.0,
           placement.ignoreSafeArea == false {
            Rectangle()
                .foregroundColor(colorScheme == .light ? Color.white : Color.black)
                .edgesIgnoringSafeArea(.all)
        } else {
            Rectangle()
                .foreground(placement.shade)
                .edgesIgnoringSafeArea(.all)
                .applyIf(self.presentation.dismissOnTouchOutside == true) { view in
                    // Add tap gesture outside of view to dismiss
                    view.addTapGesture {
                        self.thomasEnvironment.dismiss()
                    }
                }
            }
    }

    
    private func resolvePlacement(orientation: Orientation, windowSize: WindowSize) -> ModalPlacement {
        var placement = self.presentation.defaultPlacement
        
        let resolvedOrientation = viewControllerOptions.orientation ?? orientation
        for placementSelector in self.presentation.placementSelectors ?? [] {
            if (placementSelector.windowSize != nil && placementSelector.windowSize != windowSize) {
                continue
            }
            
            if (placementSelector.orientation != nil && placementSelector.orientation != resolvedOrientation) {
                continue
            }
            
            // its a match!
            placement = placementSelector.placement
            break
        }
    
        self.viewControllerOptions.orientation = placement.device?.orientationLock
        return placement
    }
}
