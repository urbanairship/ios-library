/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

extension Color {
    static var tappableClear: Color { Color.white.opacity(0.001) }
    static var shadowColor: Color { Color.black.opacity(0.33) }
}

extension View {
    @ViewBuilder
    func showing(isShowing: Bool) -> some View {
        if isShowing {
            self
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    func addNub(placement: InAppMessageDisplayContent.Banner.Placement?, nub: AnyView, itemSpacing: CGFloat) -> some View {
        VStack(spacing: 0) {
            if placement == .top {
                self
                nub.padding(.vertical, itemSpacing / 2)
            } else {
                nub.padding(.vertical, itemSpacing / 2)
                self
            }
        }
    }

    @ViewBuilder
    func addBackground(color: Color) -> some View {
        ZStack {
            color.ignoresSafeArea(.all).zIndex(0)
            self.zIndex(1)
        }
    }

    @ViewBuilder
    func addTapAndSwipeDismiss(placement: InAppMessageDisplayContent.Banner.Placement,
                         isPressed: Binding<Bool>,
                         tapAction: (() -> ())? = nil,
                         swipeOffset: Binding<CGFloat>,
                         onDismiss: @escaping () -> Void) -> some View {
        self.offset(x: 0, y: swipeOffset.wrappedValue)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        withAnimation(.interpolatingSpring(stiffness: 300, damping: 20)) {
                            isPressed.wrappedValue = true
                            let offset = gesture.translation.height

                            let upwardSwipeTopPlacement = (placement == .top && offset < 0)
                            let downwardSwipeBottomPlacement = (placement == .bottom && offset > 0)

                            if upwardSwipeTopPlacement || downwardSwipeBottomPlacement {
                                swipeOffset.wrappedValue = gesture.translation.height
                            }
                        }
                    }
                    .onEnded { gesture in
                        withAnimation(.interpolatingSpring(stiffness: 300, damping: 20)) {
                            isPressed.wrappedValue = false
                            let offset = gesture.translation.height
                            swipeOffset.wrappedValue = offset

                            let upwardSwipeTopPlacement = (placement == .top && offset < 0)
                            let downwardSwipeBottomPlacement = (placement == .bottom && offset > 0)

                            if upwardSwipeTopPlacement || downwardSwipeBottomPlacement {
                                onDismiss()
                            } else if let action = tapAction, offset.magnitude <= 0.1 {
                                /// If drag ends on message count it as a tap
                                action()
                            } else {
                                /// Return to origin and do nothing
                                swipeOffset.wrappedValue = 0
                            }
                        }
                    })
    }

    @ViewBuilder
    func applyAlignment(placement:InAppMessageTextInfo.Alignment) -> some View {
        switch placement {
        case .center:
            HStack {
                Spacer()
                self
                Spacer()
            }
        case .left:
            HStack {
                self
                Spacer()
            }
        case .right:
            HStack {
                Spacer()
                self
            }
        }
    }

    @ViewBuilder
    func applyTransitioningPlacement(placement:InAppMessageDisplayContent.Banner.Placement) -> some View {
        switch placement {
        case .top:
            VStack {
                self.applyTransition(placement: .top)
                Spacer()
            }
        case .bottom:
            VStack {
                Spacer()
                self.applyTransition(placement: .bottom)
            }
        }
    }

    @ViewBuilder
    private func applyTransition(
        placement: InAppMessageDisplayContent.Banner.Placement
    ) -> some View {
        if (placement == .top) {
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
    }

    @ViewBuilder
    func aspectResize(width:Double? = nil, height:Double? = nil) -> some View {
        self.modifier(AspectResize(width:width, height:height))
    }

    @ViewBuilder
    func parentClampingResize(maxWidth: CGFloat, maxHeight: CGFloat) -> some View {
        self.modifier(ParentClampingResize(maxWidth: maxWidth, maxHeight: maxHeight))
    }

    @ViewBuilder
    func addCloseButton(
        dismissButtonColor: Color,
        dismissIconResource: String,
        circleColor:Color? = nil,
        onUserDismissed: @escaping () -> Void
    ) -> some View {
        ZStack(alignment: .topTrailing) { // Align close button to the top trailing corner
            self.zIndex(0)
            CloseButton(
                dismissIconColor: dismissButtonColor,
                dismissIconResource: dismissIconResource,
                circleColor: circleColor,
                onTap: onUserDismissed
            )
            .zIndex(1)
        }
    }
}

struct CenteredGeometryReader<Content: View>: View {
    var content: (CGSize) -> Content

    init(@ViewBuilder content: @escaping (CGSize) -> Content) {
        self.content = content
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            content(size)
                .position(x: size.width / 2, y: size.height / 2)
        }
    }
}

/// Attempt to resize to specified size and clamp any size axis that exceeds parent size axis to said axis.
struct AspectResize: ViewModifier {
    var width:Double?
    var height:Double?

    func body(content: Content) -> some View {
        CenteredGeometryReader { size in
            let parentWidth = size.width
            let parentHeight = size.height

            content
                .aspectRatio(CGSize(width: width ?? parentWidth, height: height ?? parentHeight), contentMode: .fit)
                .frame(maxWidth: parentWidth, maxHeight: parentHeight)
        }
    }
}

/// Attempt to resize to specified size and clamp any size axis that exceeds parent size axis to said axis.
struct ParentClampingResize: ViewModifier {
    var maxWidth: CGFloat
    var maxHeight: CGFloat

    func body(content: Content) -> some View {
        CenteredGeometryReader { parentSize in
            let parentWidth = parentSize.width
            let parentHeight = parentSize.height

            content
                .frame(maxWidth: min(parentWidth, maxWidth), maxHeight: min(parentHeight, maxHeight))
        }
    }
}
