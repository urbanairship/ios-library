/* Copyright Airship and Contributors */


public import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

/// In-App message color
public struct InAppMessageColor: Codable, Sendable, Equatable {
    /// Raw hex string - #AARRGGBB
    public let hexColorString: String

    /// Parsed swiftUI color
    public let color: Color

    /// In-app message color initializer
    /// - Parameter hexColorString: Color represented  by hex string of the format #AARRGGBB
    public init(hexColorString: String) {
        self.hexColorString = hexColorString
        self.color = Color(AirshipColorUtils.color(hexColorString) ?? .clear)
    }

    public init(from decoder: any Decoder) throws {
        let hexColorString = try decoder.singleValueContainer().decode(String.self)
        self.init(hexColorString: hexColorString)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.hexColorString)
    }
}
