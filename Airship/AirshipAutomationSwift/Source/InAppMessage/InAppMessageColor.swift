/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

/// In-App message color
public struct InAppMessageColor: Codable, Sendable, Equatable {
    /// Raw hex string - #AARRGGBB
    public let hexColorString: String

    /// Parsed swiftUI color
    public let color: Color


    public init(hexColorString: String) {
        self.hexColorString = hexColorString
        self.color = Color(ColorUtils.color(hexColorString) ?? .clear)
    }

    public init(from decoder: Decoder) throws {
        let hexColorString = try decoder.singleValueContainer().decode(String.self)
        self.init(hexColorString: hexColorString)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.hexColorString)
    }
}
