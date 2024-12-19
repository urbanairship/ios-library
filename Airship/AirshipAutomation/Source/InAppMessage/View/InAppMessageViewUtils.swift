/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

extension View {

    @ViewBuilder
    func addBackground(color: Color) -> some View {
        ZStack {
            color.ignoresSafeArea(.all).zIndex(0)
            self.zIndex(1)
        }
    }

    @ViewBuilder
    func applyAlignment(
        placement: InAppMessageTextInfo.Alignment
    ) -> some View {
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
    func aspectResize(width:Double? = nil, height:Double? = nil) -> some View {
        self.modifier(AspectResize(width:width, height:height))
    }

    @ViewBuilder
    func parentClampingResize(maxWidth: CGFloat, maxHeight: CGFloat) -> some View {
        self.modifier(ParentClampingResize(maxWidth: maxWidth, maxHeight: maxHeight))
    }

    @ViewBuilder
    func addCloseButton(
        dismissIconResource: String,
        dismissButtonColor: Color?,
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        onUserDismissed: @escaping () -> Void
    ) -> some View {
        let dismissIconImage = InAppMessageTheme.dismissIcon(dismissIconResource)
        let defaultDismissColor = Color.white

        ZStack(alignment: .topTrailing) { // Align close button to the top trailing corner
            self.zIndex(0)
            CloseButton(
                dismissIconImage: dismissIconImage,
                dismissIconColor: dismissButtonColor ?? defaultDismissColor,
                width: width,
                height: height,
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
            content(size).position(
                x: size.width / 2,
                y: size.height / 2
            )
        }
    }
}

/// Attempt to resize to specified size and clamp any size axis that exceeds parent size axis to said axis.
struct AspectResize: ViewModifier {
    var width: Double?
    var height: Double?

    func body(content: Content) -> some View {
        CenteredGeometryReader { size in
            let parentWidth = size.width
            let parentHeight = size.height

            content.aspectRatio(
                CGSize(width: width ?? parentWidth, height: height ?? parentHeight),
                contentMode: .fit
            )
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

            content.frame(
                maxWidth: min(parentWidth, maxWidth),
                maxHeight: min(parentHeight, maxHeight)
            )
        }
    }
}
