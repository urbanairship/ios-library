/* Copyright Airship and Contributors */

import Foundation
public import SwiftUI

#if canImport(UIKit)
public import UIKit
#elseif canImport(AppKit)
public import AppKit
#endif

public struct AirshipFont {

    /// Resolves a SwiftUI Font
    @MainActor
    public static func resolveFont(
        size: Double,
        families: [String]? = nil,
        weight: Double? = nil,
        isItalic: Bool = false,
        isBold: Bool = false
    ) -> Font {
        
        let scaledSize = self.scaledSize(size)
        let fontWeight = self.resolveSwiftWeight(weight: weight, isBold: isBold)

        var font: Font
        if let fontFamily = resolveFontFamily(families: families) {
            font = Font.custom(fontFamily, fixedSize: scaledSize).weight(fontWeight)
        } else {
            font = Font.system(size: scaledSize, weight: fontWeight)
        }

        return isItalic ? font.italic() : font
    }

    /// Resolves a Native Font (UIFont or NSFont)
    @MainActor
    public static func resolveNativeFont(
        size: Double,
        families: [String]? = nil,
        weight: Double? = nil,
        isItalic: Bool = false,
        isBold: Bool = false
    ) -> AirshipNativeFont {
        let scaledSize = CGFloat(self.scaledSize(size))
        let nativeWeight = self.resolveNativeWeight(weight: weight, isBold: isBold)

        var font: AirshipNativeFont
        if let fontFamily = resolveFontFamily(families: families) {
#if os(macOS)
            font = NSFont(name: fontFamily, size: scaledSize) ?? NSFont.systemFont(ofSize: scaledSize, weight: nativeWeight)
#else
            font = UIFont(name: fontFamily, size: scaledSize) ?? UIFont.systemFont(ofSize: scaledSize, weight: nativeWeight)
#endif
        } else {
#if os(macOS)
            font = NSFont.systemFont(ofSize: scaledSize, weight: nativeWeight)
#else
            font = UIFont.systemFont(ofSize: scaledSize, weight: nativeWeight)
#endif
        }

        if isItalic {
#if os(macOS)
            let descriptor = font.fontDescriptor.withSymbolicTraits(.italic)
            font = NSFont(descriptor: descriptor, size: scaledSize) ?? font
#else
            let descriptor = font.fontDescriptor.withSymbolicTraits(.traitItalic)
            font = UIFont(descriptor: descriptor ?? font.fontDescriptor, size: 0)
#endif
        }

        return font
    }

    // MARK: - Scaling & Weights

    public static func scaledSize(_ size: Double) -> Double {
#if os(macOS)
        return size
#else
        return UIFontMetrics.default.scaledValue(for: size)
#endif
    }

    private static func resolveSwiftWeight(weight: Double?, isBold: Bool) -> Font.Weight {
        if let weight = weight {
            return swiftWeight(from: roundFontWeight(weight))
        }
        return isBold ? .bold : .regular
    }

#if os(macOS)
    private static func resolveNativeWeight(weight: Double?, isBold: Bool) -> NSFont.Weight {
        if let weight = weight {
            return nativeWeight(from: roundFontWeight(weight))
        }
        return isBold ? .bold : .regular
    }
#else
    private static func resolveNativeWeight(weight: Double?, isBold: Bool) -> UIFont.Weight {
        if let weight = weight {
            return nativeWeight(from: roundFontWeight(weight))
        }
        return isBold ? .bold : .regular
    }
#endif

    // MARK: - Internal Mappers

    private static func roundFontWeight(_ fontWeight: Double) -> Int {
        let rounded = Int(round(fontWeight / 100.0) * 100.0)
        return max(100, min(900, rounded))
    }

    private static func swiftWeight(from roundedWeight: Int) -> Font.Weight {
        let map: [Int: Font.Weight] = [
            100: .ultraLight, 200: .thin, 300: .light, 400: .regular,
            500: .medium, 600: .semibold, 700: .bold, 800: .heavy, 900: .black
        ]
        return map[roundedWeight] ?? .regular
    }

#if os(macOS)
    private static func nativeWeight(from roundedWeight: Int) -> NSFont.Weight {
        let map: [Int: NSFont.Weight] = [
            100: .ultraLight, 200: .thin, 300: .light, 400: .regular,
            500: .medium, 600: .semibold, 700: .bold, 800: .heavy, 900: .black
        ]
        return map[roundedWeight] ?? .regular
    }
#else
    private static func nativeWeight(from roundedWeight: Int) -> UIFont.Weight {
        let map: [Int: UIFont.Weight] = [
            100: .ultraLight, 200: .thin, 300: .light, 400: .regular,
            500: .medium, 600: .semibold, 700: .bold, 800: .heavy, 900: .black
        ]
        return map[roundedWeight] ?? .regular
    }
#endif

    public static func resolveFontFamily(families: [String]?) -> String? {
        guard let families = families else { return nil }
        for family in families {
            let lower = family.lowercased()
            if lower == "serif" { return "Times New Roman" }
            if lower == "sans-serif" { return nil }

#if os(macOS)
            if NSFontManager.shared.availableFontFamilies.contains(family) { return family }
#else
            if !UIFont.fontNames(forFamilyName: family).isEmpty { return family }
#endif
        }
        return nil
    }
}




