/* Copyright Airship and Contributors */

import SwiftUI
import Foundation


/// NOTE: For internal use only. :nodoc:
public struct AirshipEmbeddedSize: Equatable, Hashable, Sendable {

    /// The parent's width
    public var parentWidth: CGFloat?

    /// The parent's height
    public var parentHeight: CGFloat?

    /// Creates a new AirshipEmbeddedSize
    /// - Parameters:
    ///   - parentWidth: The parent's width in points.. This is required for horizontal scroll views to size correctly when using percent based sizing.
    ///   - parentHeight: The parent's height in points.  This is required for vertical scroll views to size correctly when using percent based sizing.
    public init(parentWidth: CGFloat? = nil, parentHeight: CGFloat? = nil) {
        self.parentWidth = parentWidth
        self.parentHeight = parentHeight
    }

    /// Creates a new AirshipEmbeddedSize
    /// - Parameters:
    ///   - maxSize: The max size that the view can grow to  in points.
    public init(parentBounds: CGSize) {
        self.parentWidth = parentBounds.width
        self.parentHeight = parentBounds.height
    }
}
