/* Copyright Airship and Contributors */

import SwiftUI
import Foundation


/// NOTE: For internal use only. :nodoc:
public struct AirshipEmbeddedSize: Equatable, Hashable, Sendable {

    /// Max width
    public var maxWidth: CGFloat?

    /// Max height
    public var maxHeight: CGFloat?

    /// Creates a new AirshipEmbeddedSize
    /// - Parameters:
    ///   - maxWidth: The max width that the view can grow to  in points. This is required for horizontal scroll views to size correctly when using percent based sizing.
    ///   - maxHeight: The max height that the view can grow to in points.  This is required for vertical scroll views to size correctly when using percent based sizing.
    public init(maxWidth: CGFloat? = nil, maxHeight: CGFloat? = nil) {
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
    }

    /// Creates a new AirshipEmbeddedSize
    /// - Parameters:
    ///   - maxSize: The max size that the view can grow to  in points.
    public init(maxSize: CGSize) {
        self.maxWidth = maxSize.width
        self.maxHeight = maxSize.height
    }
}
