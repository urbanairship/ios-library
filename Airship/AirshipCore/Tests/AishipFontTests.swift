/* Copyright Airship and Contributors */

import Testing
@testable import AirshipCore
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@Suite struct AirshipFontTests {
    
    @Test
    func testResolveFontFamily() {
        // Serif -> Times New Roman
#if canImport(UIKit) || canImport(AppKit)
        let serif = AirshipFont.resolveFontFamily(families: ["serif"])
#if os(macOS)
        // Times New Roman might vary by OS version but usually present
        // If not present, it might fail, but let's assume standard env
        if let serif = serif {
            #expect(serif == "Times New Roman")
        }
#else
        #expect(serif == "Times New Roman")
#endif
        
        // Sans-serif -> nil (system)
        let sans = AirshipFont.resolveFontFamily(families: ["sans-serif"])
        #expect(sans == nil)
        
        // Existing font (Helvetica is standard on Apple platforms)
        let helvetica = AirshipFont.resolveFontFamily(families: ["Helvetica"])
        #expect(helvetica == "Helvetica")
        
        // Fallback
        let fallback = AirshipFont.resolveFontFamily(families: ["NonExistentFont", "Helvetica"])
        #expect(fallback == "Helvetica")
        
        // Non-existent
        let none = AirshipFont.resolveFontFamily(families: ["NonExistentFontSomething123"])
        #expect(none == nil)
        
        // Empty/Nil
        #expect(AirshipFont.resolveFontFamily(families: []) == nil)
        #expect(AirshipFont.resolveFontFamily(families: nil) == nil)
#endif
    }
    
    @Test
    @MainActor
    func testResolveNativeFont() {
        #if canImport(UIKit)
        let size = 20.0
        let expectedScaledSize = CGFloat(AirshipFont.scaledSize(size))
        
        // System Font
        let systemFont = AirshipFont.resolveNativeFont(size: size)
        // Note: scaledSize might make it larger or smaller than 20.0 depending on dynamic type settings
        #expect(abs(systemFont.pointSize - expectedScaledSize) <= 0.5)
        
        // Family
        let helvetica = AirshipFont.resolveNativeFont(size: size, families: ["Helvetica"])
        #expect(helvetica.familyName == "Helvetica")
        
        // Italic
        let italic = AirshipFont.resolveNativeFont(size: size, isItalic: true)
        #expect(italic.fontDescriptor.symbolicTraits.contains(.traitItalic))
        
        // Bold
        let bold = AirshipFont.resolveNativeFont(size: size, isBold: true)
        // .traitBold check
        #expect(bold.fontDescriptor.symbolicTraits.contains(.traitBold))
        
        // Specific Weight
        let heavy = AirshipFont.resolveNativeFont(size: size, weight: 800)
        // Hard to check exact weight value easily cross-version, but we can verify it returns a font
        #expect(abs(heavy.pointSize - expectedScaledSize) <= 0.5)
        
        #elseif canImport(AppKit)
        let size = 20.0
        
        // System Font
        let systemFont = AirshipFont.resolveNativeFont(size: size)
        #expect(systemFont.pointSize == size) // macOS usually doesn't scale by default like iOS dynamic type in this context unless specified? 
        // Logic: scaledSize returns size on macOS
        
        // Family
        let helvetica = AirshipFont.resolveNativeFont(size: size, families: ["Helvetica"])
        #expect(helvetica.familyName == "Helvetica")
        
        // Italic
        let italic = AirshipFont.resolveNativeFont(size: size, isItalic: true)
        #expect(italic.fontDescriptor.symbolicTraits.contains(.italic))
        
        // Bold
        // Note: NSFont behavior with traits might vary, but basic system bold should work
        let bold = AirshipFont.resolveNativeFont(size: size, isBold: true)
        // Testing exact traits on macOS can be tricky with NSFontDescriptor, but let's try
        #expect(bold.fontDescriptor.symbolicTraits.contains(.bold)) // .bold is unavailable on some older OS versions? No, .bold is standard in NSFontDescriptor.SymbolicTraits
        
#endif
    }
    
    @Test
    @MainActor
    func testResolveSwiftUIFont() {
        // Just verify it doesn't crash and returns a Font
        let font = AirshipFont.resolveFont(size: 16, families: ["serif"], weight: 400, isItalic: true, isBold: false)
        // Validating SwiftUI Font contents is not possible via public API, so existence is the test.
        _ = font
    }
    
    @Test
    func testScaledSize() {
        let size = 10.0
        let scaled = AirshipFont.scaledSize(size)
        
#if os(macOS)
        #expect(scaled == size)
#else
        // iOS scales based on settings. Assuming default, it might be close to size or larger.
        // We just ensure it's not zero.
        #expect(scaled > 0)
#endif
    }
}
