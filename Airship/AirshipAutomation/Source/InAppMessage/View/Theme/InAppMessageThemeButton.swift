/* Copyright Airship and Contributors */

import Foundation
import SwiftUI


public extension InAppMessageTheme {

    /// Button in-app message theme
    struct Button: Equatable {
        /// Button height
        public var height: Double

        /// Button spacing when stackeds
        public var stackedSpacing: Double

        /// Button spacing when seperated
        public var separatedSpacing: Double

        /// Padding
        public var padding: EdgeInsets

        public init(
            height: Double,
            stackedSpacing: Double,
            separatedSpacing: Double,
            padding: EdgeInsets = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        ) {
            self.height = height
            self.stackedSpacing = stackedSpacing
            self.separatedSpacing = separatedSpacing
            self.padding = padding
        }

        mutating func applyOverrides(_ overrides: Overrides?) {
            guard let overrides else { return }
            self.height = overrides.buttonHeight ?? self.height
            self.stackedSpacing = overrides.stackedButtonSpacing ?? self.stackedSpacing
            self.separatedSpacing = overrides.separatedButtonSpacing ?? self.separatedSpacing
            self.padding.add(overrides.additionalPadding)
        }

        struct Overrides: Decodable {
            var buttonHeight: Double?
            var stackedButtonSpacing: Double?
            var separatedButtonSpacing: Double?
            var additionalPadding: InAppMessageTheme.AdditionalPadding?

            enum CodingKeys: String, CodingKey {
                case buttonHeight
                case stackedButtonSpacing
                case separatedButtonSpacing
                case additionalPadding
            }
        }
    }
}
