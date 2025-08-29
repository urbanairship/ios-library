/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// InAppMessage text info
public struct InAppMessageTextInfo: Sendable, Codable, Equatable {

    /// Text styles
    public enum Style: String, Sendable, Codable {
        case bold = "bold"
        case italic = "italic"
        case underline = "underline"
    }

    /// Text alignment
    public enum Alignment: String, Sendable, Codable {
        case left = "left"
        case center = "center"
        case right = "right"
    }

    /// The display text
    public var text: String

    /// The text color
    public var color: InAppMessageColor?

    /// The font size
    public var size: Double?

    /// Font families
    public var fontFamilies: [String]?

    /// Alignment
    public var alignment: Alignment?

    /// Style
    public var style: [Style]?


    /// In-app message text model
    /// - Parameters:
    ///   - text: Text
    ///   - color: Color
    ///   - size: Size
    ///   - fontFamilies: Font families
    ///   - alignment: Text alignment inside its own frame
    ///   - style: Text style
    public init(
        text: String,
        color: InAppMessageColor? = nil,
        size: Double? = nil, 
        fontFamilies: [String]? = nil,
        alignment: Alignment? = nil,
        style: [Style]? = nil
    ) {
        self.text = text
        self.color = color
        self.size = size
        self.fontFamilies = fontFamilies
        self.alignment = alignment
        self.style = style
    }

    enum CodingKeys: String, CodingKey {
        case text
        case color
        case size
        case fontFamilies = "font_family"
        case alignment
        case style
    }
}
