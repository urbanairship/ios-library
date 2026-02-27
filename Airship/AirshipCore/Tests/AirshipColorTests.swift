/* Copyright Airship and Contributors */

import Testing
@testable import AirshipCore
import SwiftUI

@Suite struct AirshipColorTests {

    @Test
    func testResolveNativeColorAARRGGBB() throws {
        let color = try #require(AirshipColor.resolveNativeColor("#FFFF0000"))

        var red: CGFloat = 0.0
        var green: CGFloat = 0.0
        var blue: CGFloat = 0.0
        var alpha: CGFloat = 0.0

        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        #expect(red == 1.0)
        #expect(green == 0)
        #expect(blue == 0)
        #expect(alpha == 1.0)

        #expect(try AirshipColor.hexString(color) == "#FFFF0000")

        // Lowercase and no hash
        let color2 = try #require(AirshipColor.resolveNativeColor("8000ff00"))
        color2.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        #expect(red == 0)
        #expect(green == 1.0)
        #expect(blue == 0)
        #expect(Double(alpha).isApproximately(0.5, within: 0.01))

        #expect(try AirshipColor.hexString(color2) == "#8000FF00")
    }

    @Test
    func testResolveNativeColorRRGGBB() throws {
        let color = try #require(AirshipColor.resolveNativeColor("FF0000"))

        var red: CGFloat = 0.0
        var green: CGFloat = 0.0
        var blue: CGFloat = 0.0
        var alpha: CGFloat = 0.0

        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        #expect(red == 1.0)
        #expect(green == 0)
        #expect(blue == 0)
        #expect(alpha == 1.0)

        // Lowercase and no hash
        let color2 = try #require(AirshipColor.resolveNativeColor("00ff80"))
        color2.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        #expect(red == 0)
        #expect(green == 1.0)
        #expect(Double(blue).isApproximately(0.5, within: 0.01))
        #expect(alpha == 1.0)
    }

    @Test
    func testResolveNativeColorInvalid() {
        #expect(AirshipColor.resolveNativeColor("Not a color") == nil)
        #expect(AirshipColor.resolveNativeColor("#FF00") == nil) // Too short
        #expect(AirshipColor.resolveNativeColor("#FFFF00FF00") == nil) // Too long
    }
    
    @Test
    func testStringToColorExtension() {
        let color = "#FFFF0000".airshipToColor()
        // verifying it returns a valid View/Color
        #expect(String(describing: color).count > 0)
    }
}

extension Double {
    func isApproximately(_ other: Double, within tolerance: Double) -> Bool {
        return abs(self - other) <= tolerance
    }
}
