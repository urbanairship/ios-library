/* Copyright Airship and Contributors */

import Foundation
public import SwiftUI

public extension InAppMessageTheme {

    /// Media in-app message theme
    struct Media: Equatable, Sendable {

        /// Padding
        public var padding: EdgeInsets

        public init(padding: EdgeInsets) {
            self.padding = padding
        }

        mutating func applyOverrides(_ overrides: Overrides?) {
            guard let overrides else { return }
            self.padding.add(overrides.additionalPadding)
        }

        struct Overrides: Decodable {
            var additionalPadding: AdditionalPadding?

            enum CodingKeys: String, CodingKey {
                case additionalPadding
            }
        }
    }
}
