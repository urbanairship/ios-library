/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipCore


final class AirshipColorUtilsTest: XCTestCase {
      /**
       * Test the parsing of 32-bit hex colors, in AARRGGBB format
       */
      func testAARRGGBB() {
          let c = AirshipColorUtils.color("#FFFF0000")!

          var red: CGFloat = 0.0, green: CGFloat = 0.0, blue: CGFloat = 0.0, alpha: CGFloat = 0.0
          c.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

          XCTAssertEqual(red, 1.0)
          XCTAssertEqual(green, 0)
          XCTAssertEqual(blue, 0)
          XCTAssertEqual(alpha, 1.0)

          XCTAssertEqual(AirshipColorUtils.hexString(c), "#ffff0000")

          // lowercase letters and no # symbol should be fine
          let c2 = AirshipColorUtils.color("8000ff00")!
          c2.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

          XCTAssertEqual(red, 0)
          XCTAssertEqual(green, 1.0)
          XCTAssertEqual(blue, 0)
          // rounding to two decimal places here, because floating point
          XCTAssertEqual(round(100 * alpha) / 100, 0.5)

          XCTAssertEqual(AirshipColorUtils.hexString(c2), "#8000ff00")
      }

      /**
       * Test the parsing of 24-bit hex colors, in RRGGBB format
       */
      func testRRGGBB() {
          let c = AirshipColorUtils.color("FF0000")!

          var red: CGFloat = 0.0, green: CGFloat = 0.0, blue: CGFloat = 0.0, alpha: CGFloat = 0.0
          c.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

          XCTAssertEqual(red, 1.0)
          XCTAssertEqual(green, 0)
          XCTAssertEqual(blue, 0)
          XCTAssertEqual(alpha, 1.0)

          // lowercase letters and no # symbol should be fine
          let c2 = AirshipColorUtils.color("00ff80")!
          c2.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

          XCTAssertEqual(red, 0)
          XCTAssertEqual(green, 1.0)
          // rounding to two decimal places here, because floating point
          XCTAssertEqual(round(100 * blue) / 100, 0.5)
          XCTAssertEqual(alpha, 1)
      }

      /**
       * Test that parsing something that's not a color doesn't blow up, and returns nil.
       */
      func testNotAColor() {
          let c = AirshipColorUtils.color("This is not a color")
          XCTAssertNil(c)
      }

      /**
       * Test that parsing something that's the wrong width doesn't blow up, and returns nil.
       */
      func testWrongWidth() {
          // too short
          let c1 = AirshipColorUtils.color("#FF00")
          XCTAssertNil(c1)
          // too long
          let c2 = AirshipColorUtils.color("#FFFF00FF00")
          XCTAssertNil(c2)
      }

}
