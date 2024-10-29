/* Copyright Airship and Contributors */

import SwiftUI

enum PagerSwipeDirection: Sendable {
    case up
    case down
    case start
    case end
}

extension PagerSwipeDirection {
    private static let flingSpeed: CGFloat = 150.0
    private static let offsetPercent: CGFloat = 0.50

    static func from(
        edge: Edge,
        layoutDirection: LayoutDirection
    ) -> PagerSwipeDirection {
        switch (edge) {
        case .top:
            return .down
        case .leading:
            return if (layoutDirection == .leftToRight) {
                .end
            } else {
                .start
            }
        case .bottom:
            return .up
        case .trailing:
            return if (layoutDirection == .leftToRight) {
                .start
            } else {
                .end
            }
        }
    }

#if !os(tvOS)
    static func from(
        dragValue: DragGesture.Value,
        size: CGSize,
        layoutDirection: LayoutDirection
    ) -> PagerSwipeDirection? {
        let xVelocity = dragValue.predictedEndLocation.x - dragValue.location.x
        let yVelocity = dragValue.predictedEndLocation.y - dragValue.location.y
        let widthOffset = dragValue.translation.width / size.width
        let heightOffset = dragValue.translation.height / size.height

        var swipeDirection: PagerSwipeDirection? = nil
        if (abs(xVelocity) > abs(yVelocity)) {
            if abs(xVelocity) >= Self.flingSpeed {
                if (xVelocity > 0) {
                    swipeDirection = (layoutDirection == .leftToRight) ? .start : .end
                } else {
                    swipeDirection = (layoutDirection == .leftToRight) ? .end : .start
                }
            } else if abs(widthOffset) >= Self.offsetPercent {
                if (widthOffset > 0) {
                    swipeDirection = (layoutDirection == .leftToRight) ? .start : .end
                } else {
                    swipeDirection = (layoutDirection == .leftToRight) ? .end : .start
                }
            }
        } else {
            if abs(yVelocity) >= Self.flingSpeed {
                swipeDirection = (yVelocity > 0) ? .down : .up
             } else if abs(heightOffset) >= Self.offsetPercent {
                 swipeDirection = (heightOffset > 0) ? .down : .up
             }
        }
        return swipeDirection
    }
#endif
}
