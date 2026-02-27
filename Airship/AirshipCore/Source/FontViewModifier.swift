/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

struct TextAppearanceViewModifier: ViewModifier
{
    let textAppearance: ThomasTextAppearance

    // Needed for dynamic font size
    @Environment(\.sizeCategory) var sizeCategory
    
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
            if #available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *) {
                self.lineHeight(.multiple(factor: multiplier))
            } else {
                // Fallback: approximate using scaled font size as base line height.
                //
                // Natural line height ~= scaledFontSize * (font's internal multiplier).
                // We don't know that exact internal multiplier in SwiftUI,
                // but using scaledFontSize as the "1.0" baseline is a reasonable approximation.
                let baseLineHeight = scaledFontSize
                let effective = baseLineHeight * multiplier
                let extra = max(effective - baseLineHeight, 0)
                self.lineSpacing(extra)
            }
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

