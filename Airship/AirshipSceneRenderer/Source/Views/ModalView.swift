/* Copyright Airship and Contributors */

import SwiftUI
@_spi(AirshipInternal) import AirshipBasement
import AirshipCore

struct ModalView: View {

    @Environment(\.colorScheme) var colorScheme

    let presentation: ThomasPresentationInfo.Modal
    let layout: AirshipLayout
    @ObservedObject
    var thomasEnvironment: ThomasEnvironment
    #if !os(watchOS)
    let viewControllerOptions: ThomasViewControllerOptions
    #endif

    let onDismiss: () -> Void

    @State private var contentSize: CGSize? = nil
    @State private var isShowing: Bool = false
    @State private var isDismissing: Bool = false
    
    static let animateInDuration = 0.2
    static let animateOutDuration = 0.3
    
    var body: some View {
        GeometryReader { metrics in
            RootView(
                thomasEnvironment: thomasEnvironment,
                layout: layout
            ) { orientation, windowSize in
                let placement = resolvePlacement(
                    orientation: orientation,
                    windowSize: windowSize
                )
                ZStack {
                    if isShowing {
                        switch placement.animation {
                        case .slide, .explode:
                            modalBackground(placement)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .transition(.opacity)
                            
                            createModalContent(placement: placement, metrics: metrics)
                                .airshipApplyModalTransition(animation: placement.animation)
                        case .fade, _:
                            createModalContent(placement: placement, metrics: metrics)
                                .background(
                                    modalBackground(placement)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                )
                                .airshipApplyModalTransition(animation: placement.animation)
                        }
                    }
                }
                .onAppear {
                    setShowing(animation: placement.animation, state: true)
                }
                .airshipOnChangeOf(thomasEnvironment.isDismissed) { _ in
                    isDismissing = true
                    setShowing(animation: placement.animation, state: false) {
                        onDismiss()
                    }
                }
            }
        }
        .allowsHitTesting(!isDismissing)
        .ignoresSafeArea(ignoreKeyboardSafeArea ? [.keyboard] : [])
    }

    private func setShowing(
        animation: ThomasPresentationInfo.Modal.Animation?,
        state: Bool,
        completion: (() -> Void)? = nil)
    {
        let duration = if (state) {
            switch animation {
            case .fade(let fadeAnimation): fadeAnimation.animateInSeconds ?? Self.animateInDuration
            case .slide(let slideAnimation): slideAnimation.animateInSeconds ?? Self.animateInDuration
            case .explode(let explodeAnimation): explodeAnimation.animateInSeconds ?? Self.animateInDuration
            default: Self.animateInDuration
            }
        } else {
            switch animation {
            case .fade(let fadeAnimation): fadeAnimation.animateOutSeconds ?? Self.animateOutDuration
            case .slide(let slideAnimation): slideAnimation.animateOutSeconds ?? Self.animateOutDuration
            case .explode(let explodeAnimation): explodeAnimation.animateOutSeconds ?? Self.animateOutDuration
            default: Self.animateOutDuration
            }
        }
        let animation: Animation = state ? .easeIn(duration: duration) : .easeOut(duration: duration)
        withAnimation(animation) {
            isShowing = state
        }

        DispatchQueue.main.asyncAfter(
            deadline: .now() + duration
        ) {
            completion?()
        }
    }

    private var ignoreKeyboardSafeArea: Bool {
        presentation.ios?.keyboardAvoidance == .overTheTop
    }

    private func createModalContent(
        placement: ThomasPresentationInfo.Modal.Placement,
        metrics: GeometryProxy
    ) -> some View {
        let ignoreSafeArea = placement.ignoreSafeArea == true
        let safeAreaInsets =
            ignoreSafeArea
            ? metrics.safeAreaInsets : ViewConstraints.emptyEdgeSet

        let alignment = Alignment(
            horizontal: placement.position?.horizontal.alignment ?? .center,
            vertical: placement.position?.vertical.alignment ?? .center
        )

        let windowConstraints = ViewConstraints(
            size: metrics.size,
            safeAreaInsets: safeAreaInsets
        )

        let contentConstraints = windowConstraints.contentConstraints(
            placement.size,
            contentSize: self.contentSize,
            margin: placement.margin
        )

        let safeAreasToIgnore: SafeAreaRegions = if ignoreSafeArea {
            [.container, .keyboard]
        } else {
            []
        }
        
        return VStack {
            ViewFactory.createView(
                self.layout.view,
                constraints: contentConstraints
            )
            .background(
                GeometryReader { contentMetrics -> Color in
                    DispatchQueue.main.async {
                        self.contentSize = contentMetrics.size
                    }
                    return Color.clear
                }
            )
            .thomasBackground(
                color: placement.backgroundColor,
                border: placement.border,
                shadow: placement.shadow
            )
            .margin(placement.margin)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        .ignoresSafeArea(safeAreasToIgnore)
        .opacity(self.contentSize == nil ? 0 : 1)
        .animation(nil, value: self.contentSize)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func modalBackground(_ placement: ThomasPresentationInfo.Modal.Placement) -> some View {
        GeometryReader { reader in
            VStack(spacing: 0) {
                if placement.isFullscreen, placement.ignoreSafeArea != true {
                    statusBarShimColor()
                        .frame(height: reader.safeAreaInsets.top)
                }

                Rectangle()
                    .foreground(placement.shade, colorScheme: colorScheme)
                    .ignoresSafeArea(.all)
                    .airshipApplyIf(self.presentation.dismissOnTouchOutside == true) {
                        view in
                        // Add tap gesture outside of view to dismiss
                        view.addTapGesture {
                            self.thomasEnvironment.dismiss()
                        }
                    }

                if placement.isFullscreen, placement.ignoreSafeArea != true {
                    statusBarShimColor()
                        .frame(height: reader.safeAreaInsets.bottom)
                }
            }
            .ignoresSafeArea(.all)
        }
    }

    private func resolvePlacement(
        orientation: ThomasOrientation,
        windowSize: ThomasWindowSize
    ) -> ThomasPresentationInfo.Modal.Placement {
        var placement = self.presentation.defaultPlacement

        #if !os(watchOS)
        let resolvedOrientation =
            viewControllerOptions.orientation ?? orientation
        #else
        let resolvedOrientation = orientation
        #endif

        for placementSelector in self.presentation.placementSelectors ?? [] {
            if placementSelector.windowSize != nil
                && placementSelector.windowSize != windowSize
            {
                continue
            }

            if placementSelector.orientation != nil
                && placementSelector.orientation != resolvedOrientation
            {
                continue
            }

            // its a match!
            placement = placementSelector.placement
            break
        }

        #if !os(watchOS)
        self.viewControllerOptions.orientation =
            placement.device?.orientationLock
        #endif
        return placement
    }

    private func statusBarShimColor() -> Color {
        #if os(tvOS) || os(watchOS) || os(macOS)
        return Color.clear
        #else

        var statusBarStyle = UIStatusBarStyle.default

        if let scene = try? AirshipSceneManager.shared.lastActiveScene,
           let sceneStyle = scene.statusBarManager?.statusBarStyle
        {
            statusBarStyle = sceneStyle
        }

        switch statusBarStyle {
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


extension ThomasPresentationInfo.Modal.Placement {
    fileprivate var isFullscreen: Bool {
        if let horizontalMargins = self.margin?.horizontalMargins, horizontalMargins > 0 {
            return false
        }

        if let verticalMargins = self.margin?.verticalMargins, verticalMargins > 0 {
            return false
        }

        if case let .percent(height) = self.size.height, height >= 100.0,
            case let .percent(width) = self.size.width, width >= 100.0
        {
            return true
        }
        return false
    }
}

private extension View {
    
    @ViewBuilder
    func airshipApplyModalTransition(
        animation: ThomasPresentationInfo.Modal.Animation?
    ) -> some View {
        switch animation {
        case .slide(let slideAnimation):
            self.transition(.move(edge: slideAnimation.origin))
        case .explode(let explodeAnimation):
            self.transition(
                .explode(enterCorner: explodeAnimation.enter, exitCorner: explodeAnimation.exit)
            )
        case .fade, _:
            self.transition(.opacity)
        }
    }
}

private extension AnyTransition {
    
    static func move(edge: ThomasEdgePosition) -> AnyTransition {
        if (edge.horizontal == .center) {
            switch edge.vertical {
            case .top: return .move(edge: .top)
            case .bottom: return .move(edge: .bottom)
            case .center: break
            }
        }
        
        if (edge.vertical == .center) {
            switch edge.horizontal {
            case .start: return .move(edge: .leading)
            case .end: return .move(edge: .trailing)
            case .center: break
            }
        }
        
        return .opacity
    }
    
    static func explode(enterCorner: ThomasCornerPosition, exitCorner: ThomasCornerPosition) -> AnyTransition {
        let insertionVerticalEdge: Edge = (enterCorner.vertical == .top) ? .top : .bottom
        let insertionHorizontalEdge: Edge = (enterCorner.horizontal == .start) ? .leading : .trailing
        let insertionTransition: AnyTransition = .move(edge: insertionVerticalEdge)
            .combined(with: .move(edge: insertionHorizontalEdge))
        
        let removalVerticalEdge: Edge = (exitCorner.vertical == .top) ? .top : .bottom
        let removalHorizontalEdge: Edge = (exitCorner.horizontal == .start) ? .leading : .trailing
        let removalTransition: AnyTransition = .move(edge: removalVerticalEdge)
            .combined(with: .move(edge: removalHorizontalEdge))
        
        return .asymmetric(insertion: insertionTransition, removal: removalTransition)
    }
}
