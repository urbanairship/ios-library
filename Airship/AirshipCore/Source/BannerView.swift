/* Copyright Airship and Contributors */

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif


struct BannerView: View {
    @Environment(\.layoutState) var layoutState
    @Environment(\.windowSize) private var windowSize
    @Environment(\.orientation) private var orientation
    @Environment(\.colorScheme) var colorScheme

    static let animationInOutDuration = 0.2

    let viewControllerOptions: ThomasViewControllerOptions
    let presentation: ThomasPresentationInfo.Banner
    let layout: AirshipLayout

    @ObservedObject
    var thomasEnvironment: ThomasEnvironment

    @ObservedObject
    var bannerConstraints: ThomasBannerConstraints

    @StateObject
    private var timer: AirshipObservableTimer

    /// The dimiss action callback
    let onDismiss: () -> Void

    @State private var isShowing: Bool = false
    @State private var swipeOffset: CGFloat = 0
    @State private var isButtonTapsDisabled: Bool = false
    @State private var contentSize: (ViewConstraints, CGSize)? = nil
    @State private var lastSize: CGSize?

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
                        .offset(x: 0, y: swipeOffset)
#if !os(tvOS)
                        .simultaneousGesture(swipeGesture(placement: placement))
#endif
                        .frame(maxWidth: .infinity)

                    Group {
                        if isShowing {
                            banner
                        } else {
                            banner.opacity(0)
                        }
                    }
                    .airshipApplyTransitioningPlacement(
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
                    setShowing(state: true)
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

        let ignoreSafeArea = placement.ignoreSafeArea == true
        var safeAreaInsets = ViewConstraints.emptyEdgeSet
        var safeAreasToIgnore: SafeAreaRegions = []

        if ignoreKeyboardSafeArea {
            safeAreasToIgnore.insert(.keyboard)
        }

        if ignoreSafeArea {
            if placement.position == .top {
                safeAreaInsets = EdgeInsets(
                    top: metrics.safeAreaInsets.top,
                    leading: metrics.safeAreaInsets.leading,
                    bottom: 0,
                    trailing: metrics.safeAreaInsets.trailing
                )
            } else {
                safeAreaInsets = EdgeInsets(
                    top: 0,
                    leading: metrics.safeAreaInsets.leading,
                    bottom: metrics.safeAreaInsets.bottom,
                    trailing: metrics.safeAreaInsets.trailing
                )
            }
        }

        let constraints = ViewConstraints(
            size: self.bannerConstraints.size,
            safeAreaInsets: safeAreaInsets
        )

        // Reuse cached size if constraints are identical
        var existingSize: CGSize?
        if constraints == self.contentSize?.0 {
            existingSize = self.contentSize?.1
        }

        let contentConstraints = constraints.contentConstraints(
            placement.size,
            contentSize: existingSize,
            margin: placement.margin
        )

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
            .margin(placement.margin)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        .background(
            GeometryReader(content: { contentMetrics -> Color in
                let size = contentMetrics.size
                DispatchQueue.main.async {
                    if self.lastSize != size {
                        self.bannerConstraints.size = size
                        self.lastSize = size
                        // Update cached size if constraints match
                        self.contentSize = (constraints, size)
                    }
                }
                return Color.airshipTappableClear
            })
        )
        .airshipApplyIf(ignoreSafeArea) { $0.edgesIgnoringSafeArea(.all)}
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
        let minSwipeDistance: CGFloat = bannerConstraints.size.height > 0
        ? min(100.0, bannerConstraints.size.height * 0.5)
        : 100.0

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
