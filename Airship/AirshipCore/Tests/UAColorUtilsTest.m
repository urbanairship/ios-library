/* Copyright Airship and Contributors */

#import <UIKit/UIKit.h>
#import "UABaseTest.h"
#import "UAColorUtils.h"

@interface UAColorUtilsTest : UABaseTest
@end

@implementation UAColorUtilsTest

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

/**
 * Test the parsing of 32-bit hex colors, in AARRGGBB format
 */
- (void)testAARRGGBB {
    UIColor *c = [UAColorUtils colorWithHexString:@"#FFFF0000"];

    CGFloat red = 0.0, green = 0.0, blue = 0.0, alpha = 0.0;
    [c getRed:&red green:&green blue:&blue alpha:&alpha];

    XCTAssertEqual(red, 1.0);
    XCTAssertEqual(green, 0);
    XCTAssertEqual(blue, 0);
    XCTAssertEqual(alpha, 1.0);

    XCTAssertEqualObjects([UAColorUtils hexStringWithColor:c], @"#ffff0000");

    // lowercase letters and no # symbol should be fine
    c = [UAColorUtils colorWithHexString:@"8000ff00"];
    [c getRed:&red green:&green blue:&blue alpha:&alpha];

    XCTAssertEqual(red, 0);
    XCTAssertEqual(green, 1.0);
    XCTAssertEqual(blue, 0);
    // rounding to two decimal places here, because floating point
    XCTAssertEqual(round(100 * alpha) /100, 0.5);

    XCTAssertEqualObjects([UAColorUtils hexStringWithColor:c], @"#8000ff00");
}

/**
 * Test the parsing of 24-bit hex colors, in RRGGBB format
 */
- (void)testRRGGBB {
    UIColor *c = [UAColorUtils colorWithHexString:@"FF0000"];

    CGFloat red = 0.0, green = 0.0, blue = 0.0, alpha = 0.0;
    [c getRed:&red green:&green blue:&blue alpha:&alpha];

    XCTAssertEqual(red, 1.0);
    XCTAssertEqual(green, 0);
    XCTAssertEqual(blue, 0);
    XCTAssertEqual(alpha, 1.0);

    // lowercase letters and no # symbol should be fine
    c = [UAColorUtils colorWithHexString:@"00ff80"];
    [c getRed:&red green:&green blue:&blue alpha:&alpha];

    XCTAssertEqual(red, 0);
    XCTAssertEqual(green, 1.0);
    // rounding to two decimal places here, because floating point
    XCTAssertEqual(round(100 * blue) /100, 0.5);
    XCTAssertEqual(alpha, 1);
}

/**
 * Test that parsing something that's not a color doesn't blow up, and returns nil.
 */
- (void)testNotAColor {
    UIColor *c = [UAColorUtils colorWithHexString:@"This is not a color"];
    XCTAssertNil(c);
}

/**
 * Test that parsing something that's the wrong width doesn't blow up, and returns nil.
 */
- (void)testWrongWidth {
    // too short
    UIColor *c = [UAColorUtils colorWithHexString:@"#FF00"];
    XCTAssertNil(c);
    // too long
    c = [UAColorUtils colorWithHexString:@"#FFFF00FF00"];
    XCTAssertNil(c);
}

@end
