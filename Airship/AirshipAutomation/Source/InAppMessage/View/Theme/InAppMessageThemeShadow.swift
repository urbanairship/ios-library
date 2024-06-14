/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// For color utils
#if canImport(AirshipCore)
import AirshipCore
#endif


public extension InAppMessageTheme {

    /// Shadow  in-app message theme
    struct Shadow: Equatable {

        /// Shadow radius
        public var radius: CGFloat

        /// X offset
        public var xOffset: CGFloat

        /// Y offset
        public var yOffset: CGFloat

        /// Shadow color
        public var color: Color

        public init(radius: CGFloat,  xOffset: CGFloat, yOffset: CGFloat, color: Color) {
            self.radius = radius
            self.xOffset = xOffset
            self.yOffset = yOffset
            self.color = color
        }

        mutating func applyOverrides(_ overrides: Overrides?) {
            guard let overrides else { return }
            self.radius = overrides.radius ?? self.radius
            self.xOffset = overrides.xOffset ?? self.xOffset
            self.yOffset = overrides.yOffset ?? self.yOffset
            self.color = overrides.color.flatMap { $0.airshipToColor() } ?? self.color
        }

        struct Overrides: Decodable {
            var radius: CGFloat?
            var xOffset: CGFloat?
            var yOffset: CGFloat?
            var color: String?

            init(radius: CGFloat? = nil, xOffset: CGFloat? = nil, yOffset: CGFloat? = nil, color: String? = nil) {
                self.radius = radius
                self.xOffset = xOffset
                self.yOffset = yOffset
                self.color = color
            }

            enum CodingKeys: String, CodingKey {
                case radius = "radius"
                case xOffset = "xOffset"
                case yOffset = "yOffset"
                case color = "colorHex"
            }
        }
    }
}
