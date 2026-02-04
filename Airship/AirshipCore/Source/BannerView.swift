/* Copyright Airship and Contributors */

import SwiftUI

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
        self._timer = StateObject(
            wrappedValue: AirshipObservableTimer(
                duration: TimeInterval(presentation.duration ?? Int(INT_MAX))
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
                    .airshipApplyTransition(
                        isTopPlacement: placement.position == .top
                    )
                }
                .airshipOnChangeOf(thomasEnvironment.isDismissed) { _ in
                    setShowing(state: false) {
                        self.swipeOffset = 0
                        onDismiss()
                    }
                    timer.onDisappear()
                }
                .onAppear {
                    timer.onAppear()
                    if contentSize != nil {
                        setShowing(state: true)
                    }
                }
                .airshipOnChangeOf(contentSize) { size in
                    if size != nil && !isShowing {
                        setShowing(state: true)
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
            vertical: placement.position == .top ? .top : .bottom
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
                isTopPlacement: placement.position == .top,
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

    private func setShowing(state: Bool, completion: (() -> Void)? = nil) {
        withAnimation(.easeInOut(duration: BannerView.animationInOutDuration)) {
            self.isShowing = state
        }

        DispatchQueue.main.asyncAfter(
            deadline: .now() + BannerView.animationInOutDuration
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
                    let upwardSwipeTopPlacement = (placement.position == .top && offset < 0)
                    let downwardSwipeBottomPlacement = (placement.position == .bottom && offset > 0)

                    if upwardSwipeTopPlacement || downwardSwipeBottomPlacement {
                        self.swipeOffset = offset
                    }
                }
            }
            .onEnded { gesture in
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 20)) {
                    let offset = gesture.translation.height
                    swipeOffset = offset

                    let upwardSwipeTopPlacement = (placement.position == .top && offset < -minSwipeDistance)
                    let downwardSwipeBottomPlacement = (placement.position == .bottom && offset > minSwipeDistance)

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
