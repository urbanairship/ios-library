/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "UAColorUtils+Internal.h"

@interface UAColorUtilsTest : XCTestCase
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
