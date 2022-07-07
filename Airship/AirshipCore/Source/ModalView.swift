/* Copyright Airship and Contributors */

import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct ModalView: View {
    
    static let keyboardPadding = 1.0
    @Environment(\.colorScheme) var colorScheme

    let presentation: ModalPresentationModel
    let layout: Layout
    @ObservedObject var thomasEnvironment: ThomasEnvironment
    #if !os(watchOS)
    @ObservedObject private var keyboardResponder = KeyboardResponder()
    let viewControllerOptions: ThomasViewControllerOptions
    #endif

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

    #if !os(watchOS)
    private func calculateKeyboardHeight(metrics: GeometryProxy) -> Double {
        guard self.keyboardResponder.keyboardHeight > 0 else { return 0.0 }
        return self.keyboardResponder.keyboardHeight - metrics.safeAreaInsets.bottom + ModalView.keyboardPadding
    }
    #endif
    
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
        let safeAreaInsets = ignoreSafeArea ? metrics.safeAreaInsets : ViewConstraints.emptyEdgeSet

        var alignment = Alignment(horizontal: placement.position?.horizontal.toAlignment() ?? .center,
                                  vertical: placement.position?.vertical.toAlignment() ?? .center)

        let windowConstraints = ViewConstraints(size: metrics.size, safeAreaInsets: safeAreaInsets)

        var contentSize: CGSize?
        if (windowConstraints == self.contentSize?.0) {
            contentSize = self.contentSize?.1
        }

        var contentConstraints = windowConstraints.contentConstraints(placement.size,
                                                                      contentSize: contentSize,
                                                                      margin: placement.margin)

        let windowHeight = windowConstraints.height ?? 0
        let contentHeight = contentConstraints.height ?? 0
        #if !os(watchOS)
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
            contentConstraints.height = windowHeight - keyboardHeight
        }
        #endif

        return VStack {
            ViewFactory.createView(model: self.layout.view,
                                   constraints: contentConstraints)
            .margin(placement.margin)
            .background(
                GeometryReader(content: { contentMetrics -> Color in
                    let size = contentMetrics.size
                    DispatchQueue.main.async {
                        self.contentSize = (windowConstraints, size)
                    }
                    return Color.clear
                })
            )
            #if !os(watchOS)
            .offset(y: -keyboardOffset)
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        .background(modalBackground(placement)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transaction { $0.animation = nil })
        .applyIf(ignoreSafeArea) { $0.edgesIgnoringSafeArea(.all) }
        .opacity(self.contentSize == nil ? 0 : 1)
        .animation(nil, value: self.contentSize?.1 ?? CGSize.zero)
    }

    @ViewBuilder
    private func modalBackground(_ placement: ModalPlacement) -> some View {
        if (placement.isFullScreen() && placement.ignoreSafeArea != true) {
            Rectangle()
                .foregroundColor(statusBarShimColor())
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
        
        #if !os(watchOS)
        let resolvedOrientation = viewControllerOptions.orientation ?? orientation
        #else
        let resolvedOrientation = orientation
        #endif
        
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
    
        #if !os(watchOS)
        self.viewControllerOptions.orientation = placement.device?.orientationLock
        #endif
        return placement
    }

    private func statusBarShimColor() -> Color {
        #if os(tvOS) || os(watchOS)
        return Color.clear
        #else

        var statusBarStyle = UIStatusBarStyle.default
        if let sceneStyle = UIApplication.shared.windows.first?.windowScene?.statusBarManager?.statusBarStyle {
            statusBarStyle = sceneStyle
        } else {
            statusBarStyle = UIApplication.shared.statusBarStyle
        }

        switch (statusBarStyle) {
        case .darkContent:
            return Color.white
        case .lightContent:
            return Color.black
        case .default:
            return self.colorScheme == .dark ? Color.black : Color.white
        @unknown default:
            return Color.black
        }
        #endif
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
private extension ModalPlacement {
    func isFullScreen() -> Bool {
        if case let .percent(height) = self.size.height, height >= 100.0,
           case let .percent(width) = self.size.width, width >= 100.0 {
            return true
        }
        return false
    }
}

