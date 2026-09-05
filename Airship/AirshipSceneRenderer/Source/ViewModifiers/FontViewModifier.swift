/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import AirshipBasement

struct TextAppearanceViewModifier: ViewModifier
{
    fileprivate let textAppearance: ThomasTextAppearance

    // Needed for dynamic font size
    @Environment(\.sizeCategory) fileprivate var sizeCategory
    
    @ViewBuilder
    func body(content: Content) -> some View {
        let baseFontSize = textAppearance.fontSize
        let scaledFontSize = AirshipFont.scaledSize(baseFontSize)
        let scaleFactor = Double(scaledFontSize) / baseFontSize
        content
            .font(self.textAppearance.font)
            .applyLineHeightMultiplier(
                textAppearance.lineHeightMultiplier,
                scaledFontSize: scaledFontSize
            )
            .applyKerning(
                textAppearance.kerning,
                scaleFactor: scaleFactor
            )
    }
}

extension Text {
    
    private func applyTextStyles(styles: [ThomasTextAppearance.TextStyle]?) -> Text {
        var text = self
        if let styles = styles {
            if styles.contains(.bold) {
                text = text.bold()
            }
            
            if styles.contains(.italic) {
                text = text.italic()
            }
            
            if styles.contains(.underlined) {
                text = text.underline()
            }
        }
        return text
    }
    
    @ViewBuilder
    @MainActor
    func textAppearance(
        _ textAppearance: ThomasTextAppearance?,
        colorScheme: ColorScheme
    ) -> some View {
        if let textAppearance = textAppearance {
            self.applyTextStyles(styles: textAppearance.styles)
                .multilineTextAlignment(
                    textAppearance.alignment?.toSwiftTextAlignment() ?? .center
                )
                .modifier(
                    TextAppearanceViewModifier(textAppearance: textAppearance)
                )
                .foreground(textAppearance.color, colorScheme: colorScheme)
        } else {
            self
        }
    }
}

extension View {

    @ViewBuilder
    @MainActor
    func applyLineHeightMultiplier(
        _ multiplier: Double?,
        scaledFontSize: Double
    ) -> some View {
        if let multiplier {
            // Approximate using the scaled font size as the base line height.
            //
            // Natural line height ~= scaledFontSize * (font's internal multiplier).
            // We don't know that exact internal multiplier in SwiftUI, but using
            // scaledFontSize as the "1.0" baseline is a reasonable approximation.
            //
            // SwiftUI's `lineHeight(.multiple(factor:))` (iOS 26+) is intentionally
            // not used here: it resolves against the font's own line height, which
            // produces different results than Android. This approximation matches
            // Android's line height handling more closely.
            let baseLineHeight = scaledFontSize
            let effective = baseLineHeight * multiplier
            let extra = max(effective - baseLineHeight, 0)
            self
                .lineSpacing(extra)
                .frame(minHeight: effective, alignment: .top)
        } else {
            self
        }
    }

    @ViewBuilder
    @MainActor
    fileprivate func applyKerning(
        _ kerning: Double?,
        scaleFactor: Double
    ) -> some View {
        if let kerning {
            self.kerning(kerning * scaleFactor)
        } else {
            self
        }
    }

    @ViewBuilder
    func applyViewAppearance(
        _ textAppearance: ThomasTextAppearance?,
        colorScheme: ColorScheme
    ) -> some View {
        if let textAppearance = textAppearance {
            self
                .multilineTextAlignment(
                    textAppearance.alignment?.toSwiftTextAlignment() ?? .center
                )
                .modifier(
                    TextAppearanceViewModifier(textAppearance: textAppearance)
                )
                .foreground(textAppearance.color, colorScheme: colorScheme)
        } else {
            self
        }
    }
}

