/* Copyright Airship and Contributors */

import Foundation
public import SwiftUI

public extension InAppMessageTheme {

    /// Text in-app message theme
    struct Text: Equatable {
        
        /// Letter spacing
        public var letterSpacing: CGFloat
        
        /// Line spacing
        public var lineSpacing: CGFloat

        /// Text view padding
        public var padding: EdgeInsets

        public init(letterSpacing: Double, lineSpacing: Double, padding: EdgeInsets) {
            self.letterSpacing = letterSpacing
            self.lineSpacing = lineSpacing
            self.padding = padding
        }

        mutating func applyOverrides(_ overrides: Overrides?) {
            guard let overrides else { return }
            self.letterSpacing = overrides.letterSpacing ?? self.letterSpacing
            self.lineSpacing = overrides.lineSpacing ?? self.lineSpacing
            self.padding.add(overrides.additionalPadding)
        }

        struct Overrides: Decodable {
            var letterSpacing: CGFloat?
            var lineSpacing: CGFloat?
            var additionalPadding: InAppMessageTheme.AdditionalPadding?
        }
    }
}
