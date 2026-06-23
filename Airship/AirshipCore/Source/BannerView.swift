/* Copyright Airship and Contributors */

import SwiftUI
@_spi(AirshipInternal) import AirshipBasement

#if canImport(UIKit)
import UIKit
#endif

struct BannerView: View {
    @Environment(\.layoutState) private var layoutState
    @Environment(\.windowSize) private var windowSize
    @Environment(\.orientation) private var orientation
    @Environment(\.colorScheme) private var colorScheme

    static let animationInOutDuration = 0.2
    
    private let viewControllerOptions: ThomasViewControllerOptions
    private let presentation: ThomasPresentationInfo.Banner
    private let layout: AirshipLayout

    @ObservedObject
    private var thomasEnvironment: ThomasEnvironment

    @ObservedObject
    private var bannerConstraints: ThomasBannerConstraints

    @StateObject
    private var timer: AirshipObservableTimer

    /// The dismiss action callback
    private let onDismiss: () -> Void

    @State private var isShowing: Bool = false
    @State private var swipeOffset: CGFloat = 0
    @State private var isButtonTapsDisabled: Bool = false
    @State private var contentSize: CGSize? = nil

    init(
        viewControllerOptions: ThomasViewControllerOptions,
        presentation: ThomasPresentationInfo.Banner,
        layout: AirshipLayout,
        thomasEnvironment: ThomasEnvironment,
        bannerConstraints: ThomasBannerConstraints,
        onDismiss: @escaping () -> Void
    ) {
        self.viewControllerOptions = viewControllerOptions
        self.presentation = presentation
        self.layout = layout
        self.thomasEnvironment = thomasEnvironment
        self.bannerConstraints = bannerConstraints
        let durationMs = presentation.duration ?? Int(INT_MAX)
        self._timer = StateObject(
            wrappedValue: AirshipObservableTimer(
                duration: TimeInterval(durationMs) / 1000.0
            )
        )
        self.onDismiss = onDismiss
    }

    var body: some View {
        ZStack {
            GeometryReader { metrics in
                RootView(
                    thomasEnvironment: thomasEnvironment,
                    layout: layout
                ) { orientation, windowSize in
                    let placement = resolvePlacement(
                        orientation: orientation,
                        windowSize: windowSize
                    )

                    let banner = createBanner(
                        placement: placement,
                        metrics: metrics
                    )
                    Group {
                        if isShowing {
                            banner
                        } else {
                            banner.opacity(0)
                        }
                    }
                    .airshipApplyBannerTransition(
                        isTopPlacement: placement.position.vertical == .top,
                        animation: placement.animation
                    )
                    .airshipOnChangeOf(thomasEnvironment.isDismissed) { _ in
                        setShowing(state: false, animation: placement.animation) {
                            self.swipeOffset = 0
                            onDismiss()
                        }
                        timer.onDisappear()
                    }
                    .onAppear {
                        timer.onAppear()
                        if contentSize != nil {
                            setShowing(state: true, animation: placement.animation)
                        }
                    }
                    .airshipOnChangeOf(contentSize) { size in
                        if size != nil && !isShowing {
                            setShowing(state: true, animation: placement.animation)
                        }
                    }
                }
                
                .airshipOnChangeOf(swipeOffset) { value in
                    self.isButtonTapsDisabled = value != 0
                    self.timer.isPaused = value != 0
                }
                .onReceive(timer.$isExpired) { expired in
                    if expired {
                        self.thomasEnvironment.dismiss()
                    }
                }
                // Invalidate cached content size on orientation change
                .airshipOnChangeOf(orientation) { _ in
                    self.contentSize = nil
                }
            }
            .id(orientation)
            .ignoresSafeArea(ignoreKeyboardSafeArea ? [.keyboard] : [])
        }
    }

    private var ignoreKeyboardSafeArea: Bool {
        presentation.ios?.keyboardAvoidance == .overTheTop
    }

    @ViewBuilder
    private func nub(placement: ThomasPresentationInfo.Banner.Placement) -> some View {
        if let nubInfo = placement.nubInfo {
            Capsule()
                .frame(
                    width: nubInfo.size.width.calculateSize(nil) ?? 36,
                    height: nubInfo.size.height.calculateSize(nil) ?? 4
                )
                .foregroundColor(nubInfo.color.toColor(colorScheme))
                .margin(nubInfo.margin)
        } else {
            Capsule()
                .frame(width: 36, height: 4)
                .foregroundColor(Color.red.opacity(0.42))
        }
    }

    private func createBanner(
        placement: ThomasPresentationInfo.Banner.Placement,
        metrics: GeometryProxy
    ) -> some View {
        let alignment = Alignment(
            horizontal: .center,
            vertical: placement.position.vertical == .top ? .top : .bottom
        )

        let constraints = ViewConstraints(
            size: self.bannerConstraints.windowSize,
            safeAreaInsets: placement.ignoreSafeArea != true ? EdgeInsets() : metrics.safeAreaInsets
        )

        let contentConstraints = constraints.contentConstraints(
            placement.size,
            contentSize: self.contentSize,
            margin: placement.margin
        )

        /**
         * Banners rely on the viewController to reduce the parent view to avoid blocking the underlying view from recieving taps outside of the
         * banner. When we adjust the view controller size, it also adjusts the GeometryReader metrics making them inaccurate. We still use the metrics to get safe area insets,
         * but when calculating the size we need to use the window size in the shared bannerConstraints. Placement margins are also handled by the
         * viewController to avoid margins being touchable dead areas.
         */
        return VStack {
            ViewFactory.createView(
                layout.view,
                constraints: contentConstraints
            )
            .airshipAddNub(
                isTopPlacement: placement.position.vertical == .top,
                nub: AnyView(nub(placement: placement)),
                itemSpacing: 16
            )
            .thomasBackground(
                color: placement.backgroundColor,
                border: placement.border
            )
            .offset(x: 0, y: swipeOffset)
#if !os(tvOS)
            .simultaneousGesture(swipeGesture(placement: placement))
#endif
            .background(
                GeometryReader(content: { contentMetrics -> Color in
                    let size = contentMetrics.size
                    DispatchQueue.main.async {
                        self.bannerConstraints.updateContentSize(
                            size,
                            constraints: contentConstraints,
                            placement: placement
                        )
                        if self.contentSize != size {
                            // Update cached size if constraints match
                            self.contentSize = size
                        }
                    }
                    return Color.airshipTappableClear
                })
            )
           
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        .edgesIgnoringSafeArea(.all)
        .accessibilityElement(children: .contain)
        .accessibilityAction(.escape) {
            onDismiss()
        }
    }

    private func resolvePlacement(
        orientation: ThomasOrientation,
        windowSize: ThomasWindowSize
    ) -> ThomasPresentationInfo.Banner.Placement {

        var placement = presentation.defaultPlacement
        for placementSelector in presentation.placementSelectors ?? [] {
            if let requiredSize = placementSelector.windowSize,
               requiredSize != windowSize {
                continue
            }

            if let requiredOrientation = placementSelector.orientation,
               requiredOrientation != orientation {
                continue
            }

            // its a match!
            placement = placementSelector.placement
        }

        viewControllerOptions.bannerPlacement = placement
        return placement
    }

    private func setShowing(state: Bool, animation: ThomasPresentationInfo.Banner.Animation? , completion: (() -> Void)? = nil) {
        let duration = if (state) {
            switch animation {
            case .fade(let fadeAnimation): fadeAnimation.animateInSeconds ?? BannerView.animationInOutDuration
            case .slide(let slideAnimation): slideAnimation.animateInSeconds ?? BannerView.animationInOutDuration
            default: BannerView.animationInOutDuration
            }
        } else {
            switch animation {
            case .fade(let fadeAnimation): fadeAnimation.animateOutSeconds ?? BannerView.animationInOutDuration
            case .slide(let slideAnimation): slideAnimation.animateOutSeconds ?? BannerView.animationInOutDuration
            default: BannerView.animationInOutDuration
            }
        }
        let animation: Animation = state ? .easeIn(duration: duration) : .easeOut(duration: duration)
        withAnimation(animation) {
            self.isShowing = state
        }

        DispatchQueue.main.asyncAfter(
            deadline: .now() + duration
        ) {
            completion?()
        }
    }

#if !os(tvOS)
    private func swipeGesture(placement: ThomasPresentationInfo.Banner.Placement) -> some Gesture {
        let minSwipeDistance: CGFloat = if let height = self.contentSize?.height, height > 0 {
            min(100.0, height * 0.5)
        } else {
            100.0
        }

        return DragGesture(minimumDistance: 10)
            .onChanged { gesture in
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 20)) {
                    let offset = gesture.translation.height
                    let upwardSwipeTopPlacement = (placement.position.vertical == .top && offset < 0)
                    let downwardSwipeBottomPlacement = (placement.position.vertical == .bottom && offset > 0)

                    if upwardSwipeTopPlacement || downwardSwipeBottomPlacement {
                        self.swipeOffset = offset
                    }
                }
            }
            .onEnded { gesture in
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 20)) {
                    let offset = gesture.translation.height
                    swipeOffset = offset

                    let upwardSwipeTopPlacement = (placement.position.vertical == .top && offset < -minSwipeDistance)
                    let downwardSwipeBottomPlacement = (placement.position.vertical == .bottom && offset > minSwipeDistance)

                    if upwardSwipeTopPlacement || downwardSwipeBottomPlacement {
                        thomasEnvironment.dismiss()
                    } else {
                        // Return to origin
                        swipeOffset = 0
                    }
                }
            }
    }
#endif
}

private extension View {
    @ViewBuilder
    func airshipApplyBannerTransition(
        isTopPlacement: Bool,
        animation: ThomasPresentationInfo.Banner.Animation?
    ) -> some View {
        switch animation {
        case .slide:
            if isTopPlacement {
                self.transition(
                    .asymmetric(
                        insertion: .move(edge: .top),
                        removal: .move(edge: .top).combined(with: .opacity)
                    )
                )
            } else {
                self.transition(
                    .asymmetric(
                        insertion: .move(edge: .bottom),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    )
                )
            }
        case .fade, _:
            self.transition(.opacity)
        }
    }

    @ViewBuilder
    func airshipAddNub(
        isTopPlacement: Bool,
        nub: AnyView,
        itemSpacing: CGFloat
    ) -> some View {
        VStack(spacing: 0) {
            if isTopPlacement {
                self
                nub.padding(.vertical, itemSpacing / 2)
            } else {
                nub.padding(.vertical, itemSpacing / 2)
                self
            }
        }
    }

}
