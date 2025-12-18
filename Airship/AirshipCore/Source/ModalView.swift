/* Copyright Airship and Contributors */

import SwiftUI


struct ModalView: View {

    @Environment(\.colorScheme) var colorScheme

    let presentation: ThomasPresentationInfo.Modal
    let layout: AirshipLayout
    @ObservedObject
    var thomasEnvironment: ThomasEnvironment
    #if !os(watchOS)
    let viewControllerOptions: ThomasViewControllerOptions
    #endif

    @State private var contentSize: CGSize? = nil

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
                createModal(placement: placement, metrics: metrics)
            }
        }
        .ignoresSafeArea(ignoreKeyboardSafeArea ? [.keyboard] : [])
    }

    private var ignoreKeyboardSafeArea: Bool {
        presentation.ios?.keyboardAvoidance == .overTheTop
    }

    private func createModal(
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
        .background(
            modalBackground(placement)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        )
        .ignoresSafeArea(safeAreasToIgnore)
        .opacity(self.contentSize == nil ? 0 : 1)
        .animation(nil, value: self.contentSize)
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
        #if os(tvOS) || os(watchOS)
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
        if let horiztonalMargins = self.margin?.horiztonalMargins, horiztonalMargins > 0 {
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
