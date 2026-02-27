/* Copyright Airship and Contributors */

public import SwiftUI

#if canImport(UIKit)
public import UIKit
public typealias AirshipNativeColor = UIColor
#elseif canImport(AppKit)
public import AppKit
public typealias AirshipNativeColor = NSColor
#endif

public enum AirshipColorError: Error {
    /// Thrown when a color cannot be converted to an RGB space
    case incompatibleColorSpace(AirshipNativeColor)
}

/// Airship Color utility.
public struct AirshipColor {

    /// Resolves a SwiftUI Color from hex.
    /// - Parameters:
    ///   - string: The hex string.
    /// - Returns: The resolved Color or nil.
    public static func resolveHexColor(_ string: String) -> Color? {
        if isHexString(string) {
            if let native = resolveNativeColor(string) {
                return Color(native)
            }
        }
        return nil
    }

    /// Resolves a SwiftUI Color from hex or named string
    /// - Parameters:
    ///   - string: The hex or named string
    ///   - bundle: The bundle to look for the named color in. Defaults to `.main`.
    /// - Returns: The resolved Color
    public static func resolveColor(_ string: String, bundle: Bundle = .main) -> Color {
        if isHexString(string) {
            if let native = resolveNativeColor(string) {
                return Color(native)
            }
        }
        return Color(string, bundle: bundle)
    }

    /// Resolves a Native Color (UIColor or NSColor) from hex
    /// - Parameters:
    ///   - hexString: The hex string, can be with or without #, 6 or 8 characters.
    /// - Returns: The resolved native color, or nil if the string is invalid.
    public static func resolveNativeColor(_ hexString: String) -> AirshipNativeColor? {
        let string = normalize(hexString)
        let width = 8 * (string.count / 2)

        guard width == 32 || width == 24 else { return nil }

        var component: UInt64 = 0
        let scanner = Scanner(string: string)
        guard scanner.scanHexInt64(&component) else { return nil }

        let red = CGFloat((component & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((component & 0xFF00) >> 8) / 255.0
        let blue = CGFloat((component & 0xFF)) / 255.0

        let alpha: CGFloat = if width == 24 {
            1.0
        } else {
            CGFloat((component & 0xFF00_0000) >> 24) / 255.0
        }

        return AirshipNativeColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    /// Converts a Native Color back to an ARGB hex string (#AARRGGBB)
    /// - Parameter color: The color to convert.
    /// - Throws: `AirshipColorError.incompatibleColorSpace` if the color components cannot be extracted
    /// - Returns: The hex string in #AARRGGBB format.
    public static func hexString(_ color: AirshipNativeColor) throws -> String {
#if os(macOS)
        // Ensure we have a color space that supports RGB components
        // Dynamic system colors or pattern colors will crash getRed otherwise.
        let convertedColor = color.usingColorSpace(.sRGB) ?? color

        // On macOS, getRed is void. We check component count to verify compatibility.
        guard convertedColor.numberOfComponents >= 3 else {
            throw AirshipColorError.incompatibleColorSpace(color)
        }
#else
        let convertedColor = color
        // On iOS, getRed returns a Bool.
        guard convertedColor.getRed(nil, green: nil, blue: nil, alpha: nil) else {
            throw AirshipColorError.incompatibleColorSpace(color)
        }
#endif

        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        convertedColor.getRed(&r, green: &g, blue: &b, alpha: &a)

        return String(
            format: "#%02X%02X%02X%02X",
            Int(round(a * 255)),
            Int(round(r * 255)),
            Int(round(g * 255)),
            Int(round(b * 255))
        )
    }

    private static func isHexString(_ string: String) -> Bool {
        let hexPattern = "^#?([A-Fa-f0-9]{8}|[A-Fa-f0-9]{6})$"
        return string.range(of: hexPattern, options: .regularExpression) != nil
    }

    private static func normalize(_ hexString: String) -> String {
        var string = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if string.hasPrefix("#") { string.removeFirst() }
        return string
    }
}


public extension String {
    /// - Note: For internal use only. :nodoc:
    func airshipToColor(_ bundle:Bundle = Bundle.main) -> Color {
        return AirshipColor.resolveColor(self, bundle: bundle)
    }

    /// - Note: For internal use only. :nodoc:
    func airshipHexToNativeColor() -> AirshipNativeColor? {
        return AirshipColor.resolveNativeColor(self)
    }
}

public extension ColorScheme {

    /// Resolves a SwiftUI Color based on the scheme
    /// - Parameters:
    ///   - light: The light color
    ///   - dark: The dark color
    /// - Returns: The resolved color for the current scheme
    /// - Note: For internal use only. :nodoc:
    func airshipResolveColor(light: Color?, dark: Color?) -> Color? {
        switch self {
        case .dark:
            return dark ?? light
        case .light:
            return light
        @unknown default:
            return light
        }
    }

    /// Resolves the Native Color (NSColor or UIColor) based on the scheme
    /// - Parameters:
    ///   - light: The light color
    ///   - dark: The dark color
    /// - Returns: The resolved native color for the current scheme
    /// - Note: For internal use only. :nodoc:
    func airshipResolveNativeColor(
        light: AirshipNativeColor?,
        dark: AirshipNativeColor?
    ) -> AirshipNativeColor? {
        switch self {
        case .dark:
            return dark ?? light
        case .light:
            return light
        @unknown default:
            return light
        }
    }

    /// Bridge helper to resolve Native colors as SwiftUI Colors
    /// - Parameters:
    ///   - light: The light color
    ///   - dark: The dark color
    /// - Returns: The resolved color for the current scheme
    /// - Note: For internal use only. :nodoc:
    func airshipResolveColor(
        light: AirshipNativeColor?,
        dark: AirshipNativeColor?
    ) -> Color? {
        let resolved = self.airshipResolveNativeColor(light: light, dark: dark)
        return resolved.map { Color($0) }
    }
}
