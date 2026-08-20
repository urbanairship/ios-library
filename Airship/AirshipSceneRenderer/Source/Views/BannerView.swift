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
    @Environment(\.layoutDirection) private var layoutDirection

    static let animationInOutDuration: Double = 0.3

    /// A drag released without a fling toward the dismiss edge dismisses when it
    /// covers at least this fraction of the banner's extent along the swipe axis.
    private static let idleDismissDragFraction: CGFloat = 0.4

    /// A drag released with a fling toward the dismiss edge dismisses when it
    /// covers more than this fraction of the banner's extent along the swipe axis.
    private static let flingDismissDragFraction: CGFloat = 0.1

    /// Absolute drag distance along the swipe axis that dismisses when the
    /// banner's extent is unknown (e.g. right after rotation clears the cached
    /// content size).
    private static let fallbackDismissDistance: CGFloat = 100
    
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
        presentation: ThomasPresentationInfo.Banner,
        layout: AirshipLayout,
        thomasEnvironment: ThomasEnvironment,
        bannerConstraints: ThomasBannerConstraints,
        onDismiss: @escaping () -> Void
    ) {
        self.presentation = presentation
        self.layout = layout
        self.thomasEnvironment = thomasEnvironment
        self.bannerConstraints = bannerConstraints
        // A nil duration never starts a timer, so the banner never auto-dismisses
        self._timer = StateObject(
            wrappedValue: AirshipObservableTimer(duration: presentation.durationSeconds)
        )
        self.onDismiss = onDismiss
    }

    var body: some View {
        ZStack {
            GeometryReader { metrics in
                RootView(
                    thomasEnvironment: thomasEnvironment,
                    layout: layout,
                    initialWindowSize: bannerConstraints.windowSize
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
                        position: placement.position,
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
            }
            .ignoresSafeArea(ignoreKeyboardSafeArea ? [.keyboard] : [])
        }
    }

    private var ignoreKeyboardSafeArea: Bool {
        presentation.ios?.keyboardAvoidance == .overTheTop
    }

    private func createBanner(
        placement: ThomasPresentationInfo.Banner.Placement,
        metrics: GeometryProxy
    ) -> some View {
        let alignment = placement.position.asPosition.alignment

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
            thomasEnvironment.viewFactory.createView(
                layout.view,
                constraints: contentConstraints
            )
            .thomasBackground(
                color: placement.backgroundColor,
                border: placement.border,
                shadow: placement.shadow
            )
            .offset(
                x: placement.position.vertical == .center ? swipeOffset : 0,
                y: placement.position.vertical == .center ? 0 : swipeOffset
            )
#if !os(tvOS)
            .airshipApplyIf(placement.isSwipeToDismissEnabled) { view in
                view.simultaneousGesture(swipeGesture(placement: placement))
            }
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
        let position = placement.position
        let isVerticalSwipe = position.vertical != .center

        return DragGesture(minimumDistance: 10)
            .onChanged { gesture in
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 20)) {
                    let offset = isVerticalSwipe ? gesture.translation.height : gesture.translation.width
                    if Self.isTowardDismissEdge(offset, position: position, layoutDirection: layoutDirection) {
                        self.swipeOffset = offset
                    }
                }
            }
            .onEnded { gesture in
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 20)) {
                    let offset = isVerticalSwipe ? gesture.translation.height : gesture.translation.width
                    let predictedOffset = isVerticalSwipe
                        ? gesture.predictedEndTranslation.height
                        : gesture.predictedEndTranslation.width
                    swipeOffset = offset

                    let shouldDismiss = Self.shouldDismissOnSwipe(
                        offset: offset,
                        predictedEndOffset: predictedOffset,
                        extent: isVerticalSwipe ? self.contentSize?.height : self.contentSize?.width,
                        position: position,
                        layoutDirection: layoutDirection
                    )

                    if shouldDismiss {
                        thomasEnvironment.dismiss()
                    } else {
                        // Return to origin
                        swipeOffset = 0
                    }
                }
            }
    }

    /// Whether releasing a drag along the swipe axis should dismiss the banner.
    /// `extent` is the banner's size along the swipe axis, or nil when unknown.
    static func shouldDismissOnSwipe(
        offset: CGFloat,
        predictedEndOffset: CGFloat,
        extent: CGFloat?,
        position: ThomasEdgePosition,
        layoutDirection: LayoutDirection
    ) -> Bool {
        guard isTowardDismissEdge(offset, position: position, layoutDirection: layoutDirection) else {
            return false
        }

        // Fling: the predicted end position continues past the release
        // point toward the dismiss edge. Flings back toward the resting
        // position never dismiss.
        let isFlingTowardDismissEdge = isTowardDismissEdge(
            predictedEndOffset - offset,
            position: position,
            layoutDirection: layoutDirection
        )

        guard let extent, extent > 0 else {
            // Extent unknown (e.g. right after rotation clears the cached
            // content size): fall back to an absolute drag distance or a
            // fling toward the dismiss edge.
            return abs(offset) > Self.fallbackDismissDistance || isFlingTowardDismissEdge
        }

        let dragFraction = abs(offset) / extent
        return dragFraction >= Self.idleDismissDragFraction ||
            (isFlingTowardDismissEdge && dragFraction > Self.flingDismissDragFraction)
    }

    /// Whether a drag offset along the swipe axis moves the banner toward its dismiss edge.
    /// Banners anchored to a vertical edge dismiss toward that edge; vertically-centered
    /// banners dismiss toward their horizontal edge.
    static func isTowardDismissEdge(
        _ offset: CGFloat,
        position: ThomasEdgePosition,
        layoutDirection: LayoutDirection
    ) -> Bool {
        guard offset != 0 else { return false }
        switch position.vertical {
        case .top:
            return offset < 0
        case .bottom:
            return offset > 0
        case .center:
            let towardLeading = layoutDirection == .rightToLeft ? offset > 0 : offset < 0
            return position.horizontal == .start ? towardLeading : !towardLeading
        }
    }
#endif
}

extension ThomasEdgePosition {
    /// The edge a banner slides in from and out to. The vertical edge wins for corners;
    /// vertically-centered banners slide from their horizontal edge.
    var bannerSlideEdge: Edge {
        switch vertical {
        case .top: return .top
        case .bottom: return .bottom
        case .center:
            switch horizontal {
            case .start: return .leading
            case .end: return .trailing
            case .center:
                // Unreachable: ThomasEdgePosition requires at least one non-center axis
                assertionFailure("ThomasEdgePosition invariant violated: both axes are center")
                return .top
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func airshipApplyBannerTransition(
        position: ThomasEdgePosition,
        animation: ThomasPresentationInfo.Banner.Animation?
    ) -> some View {
        switch animation {
        // A missing animation defaults to slide-from-placement-edge to match Android
        case .slide, nil:
            let edge = position.bannerSlideEdge
            self.transition(
                .asymmetric(
                    insertion: .move(edge: edge),
                    removal: .move(edge: edge).combined(with: .opacity)
                )
            )
        case .fade:
            self.transition(.opacity)
        }
    }
}
