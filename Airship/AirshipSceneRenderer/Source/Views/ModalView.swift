/* Copyright Airship and Contributors */

import SwiftUI
@_spi(AirshipInternal) import AirshipBasement

struct ModalView: View {

    @Environment(\.colorScheme) var colorScheme

    let presentation: ThomasPresentationInfo.Modal
    let layout: AirshipLayout
    @ObservedObject
    var thomasEnvironment: ThomasEnvironment

    /// Window size at display time, so the first frame resolves against the real window.
    let initialWindowSize: CGSize

    let onDismiss: () -> Void

    @State private var contentSize: CGSize? = nil
    @State private var isShowing: Bool = false
    @State private var isDismissing: Bool = false
    
    private static let animateInDuration: Double = 0.2
    private static let animateOutDuration: Double = 0.3
    
    var body: some View {
        GeometryReader { metrics in
            RootView(
                thomasEnvironment: thomasEnvironment,
                layout: layout,
                initialWindowSize: initialWindowSize
            ) { orientation, windowSize in
                let placement = resolvePlacement(
                    orientation: orientation,
                    windowSize: windowSize
                )
                ZStack {
                    if isShowing {
                        if placement.transition?.isPlainFade ?? true {
                            createModalContent(placement: placement, metrics: metrics)
                                .background(
                                    modalBackground(placement)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                )
                                .airshipApplyModalTransition(transition: placement.transition)
                        } else {
                            modalBackground(placement)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .transition(.opacity)

                            createModalContent(placement: placement, metrics: metrics)
                                .airshipApplyModalTransition(transition: placement.transition)
                        }
                    }
                }
                .onAppear {
                    setShowing(transition: placement.transition, state: true)
                }
                .airshipOnChangeOf(thomasEnvironment.isDismissed) { _ in
                    isDismissing = true
                    setShowing(transition: placement.transition, state: false) {
                        onDismiss()
                    }
                }
            }
        }
        .allowsHitTesting(!isDismissing)
        .ignoresSafeArea(ignoreKeyboardSafeArea ? [.keyboard] : [])
    }

    private func setShowing(
        transition: ThomasPresentationInfo.Modal.Transition?,
        state: Bool,
        completion: (() -> Void)? = nil)
    {
        let duration = if state {
            transition?.enter.durationMilliseconds.map { Double($0) / 1000 } ?? Self.animateInDuration
        } else {
            transition?.exit.durationMilliseconds.map { Double($0) / 1000 } ?? Self.animateOutDuration
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

        // The placement's border is drawn inside the size the author declared, so the content is
        // sized to that size less the stroke on both edges and the border modifier's padding brings
        // the footprint back to what was asked for.
        let strokeWidth = placement.border?.strokeWidth ?? 0
        let placementStroke = CGFloat(strokeWidth * 2)

        let contentConstraints = windowConstraints.contentConstraints(
            placement.size,
            contentSize: self.contentSize,
            margin: placement.margin,
            borderStrokeWidth: strokeWidth
        )

        // Min_height / min_width floor, in points. Kept as a frame below, after the content, so the
        // modal still stands at its floor if it is ever handed a layout whose root declines to.
        // `contentConstraints` carries the same floor down as `minHeight`/`minWidth`, which is what
        // holds the content itself open — and what a percentage inside it takes its share of.
        //
        // Less the stroke, like every other bound: this frame sits inside the border modifier, so a
        // floor left at its declared value would hold the content open to the whole footprint and
        // the modal would stand a stroke too tall on each edge.
        let parentWidth = windowConstraints.width?.subtract(
            placement.margin?.horizontalMargins ?? 0
        )
        let parentHeight = windowConstraints.height?.subtract(
            placement.margin?.verticalMargins ?? 0
        )
        let minWidthFloor = placement.size.minWidth?.calculateSize(parentWidth)
            .map { max(0, $0 - placementStroke) }
        let minHeightFloor = placement.size.minHeight?.calculateSize(parentHeight)
            .map { max(0, $0 - placementStroke) }

        let safeAreasToIgnore: SafeAreaRegions = if ignoreSafeArea {
            [.container, .keyboard]
        } else {
            []
        }

        return VStack {
            thomasEnvironment.viewFactory.createView(
                self.layout.view,
                constraints: contentConstraints.deductingBorder(of: self.layout.view)
            )
            .background(
                GeometryReader { contentMetrics -> Color in
                    let measured = contentMetrics.size
                    DispatchQueue.main.async {
                        // A zero is not an answer about how tall the content is, and taking it as
                        // one made a capped auto-height modal jitter forever: zero fails the
                        // comparison against the ceiling, so the length is dropped, so a scroll
                        // inside goes back to hugging its full content, so the modal measures its
                        // uncapped self and caps again. Nothing here can legitimately be zero, so
                        // the last real measurement stands.
                        guard measured.width > 0, measured.height > 0 else { return }
                        self.contentSize = measured
                    }
                    return Color.clear
                }
            )
            .airshipApplyIf(minWidthFloor != nil || minHeightFloor != nil) { view in
                view.frame(
                    minWidth: minWidthFloor,
                    minHeight: minHeightFloor,
                    alignment: .center
                )
            }
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
                    .foreground(placement.shade, colorScheme: colorScheme, fallbackColor: .airshipTappableClear)
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

        // Resolve against the orientation we are actually in. `lock_orientation` used to override
        // this, which only held together while it also rotated the scene to match -- without that
        // it dresses a landscape window in a layout designed for portrait.
        let resolvedOrientation = orientation

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

        return placement
    }

    private func statusBarShimColor() -> Color {
        #if os(tvOS) || os(watchOS) || os(macOS)
        return Color.clear
        #else
        let statusBarStyle = thomasEnvironment.windowScene.statusBarStyle ?? .default
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
        transition: ThomasPresentationInfo.Modal.Transition?
    ) -> some View {
        if let transition {
            self.transition(
                .asymmetric(
                    insertion: .thomasTransition(for: transition.enter),
                    removal: .thomasTransition(for: transition.exit)
                )
            )
        } else {
            self.transition(.opacity)
        }
    }
}

private extension AnyTransition {

    /// The transition for one direction's own effect -- shared by insertion and removal, so a
    /// shape animates identically regardless of which side of a mixed pair it came from.
    static func thomasTransition(for effect: ThomasPresentationInfo.Modal.Effect) -> AnyTransition {
        switch effect {
        case .fade:
            return .opacity
        case .slide(let slideEffect):
            return .move(edge: slideEffect.edge)
        case .explode(let explodeEffect):
            return .move(corner: explodeEffect.corner)
        }
    }

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

    /// A diagonal move to (or from) one corner -- `insertion`/`removal` on the outer
    /// `.asymmetric` transition already say which direction this plays, so there's only ever
    /// the one corner to move against here, not an enter/exit pair.
    static func move(corner: ThomasCornerPosition) -> AnyTransition {
        let verticalEdge: Edge = (corner.vertical == .top) ? .top : .bottom
        let horizontalEdge: Edge = (corner.horizontal == .start) ? .leading : .trailing
        return .move(edge: verticalEdge).combined(with: .move(edge: horizontalEdge))
    }
}
