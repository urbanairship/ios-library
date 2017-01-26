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

#import <XCTest/XCTest.h>
#import "NSString+UAURLEncoding.h"

@interface NSString_UAURLEncodingTest : XCTestCase

@end

@implementation NSString_UAURLEncodingTest

- (void)setUp
{
    [super setUp];
    // Put setup code here; it will be run once, before the first test case.
}

- (void)tearDown
{
    // Put teardown code here; it will be run once, after the last test case.
    [super tearDown];
}

- (void)testUrlEncoding {

    NSString *simple = @"simple";
    XCTAssertEqualObjects(simple, [simple urlEncodedStringWithEncoding:NSUTF8StringEncoding], @"simple test failed");

    NSString *space = @"d e f";
    XCTAssertEqualObjects(@"d%20e%20f", [space urlEncodedStringWithEncoding:NSUTF8StringEncoding], @"space test failed");

    NSString *bang = @"go!";
    XCTAssertEqualObjects(@"go%21", [bang urlEncodedStringWithEncoding:NSUTF8StringEncoding], @"! test failed");

    NSString *quote = @"\"yes\"";
    XCTAssertEqualObjects(@"%22yes%22", [quote urlEncodedStringWithEncoding:NSUTF8StringEncoding], @"\" test failed");

    NSString *pound = @"xy#z";
    XCTAssertEqualObjects(@"xy%23z", [pound urlEncodedStringWithEncoding:NSUTF8StringEncoding], @"# test failed");

    NSString *dollar = @"$100";
    XCTAssertEqualObjects(@"%24100", [dollar urlEncodedStringWithEncoding:NSUTF8StringEncoding], @"$ test failed");

    NSString *percent = @"ab%c";
    XCTAssertEqualObjects(@"ab%25c", [percent urlEncodedStringWithEncoding:NSUTF8StringEncoding], @"percent test failed");

    NSString *ampersand = @"b&w";
    XCTAssertEqualObjects(@"b%26w", [ampersand urlEncodedStringWithEncoding:NSUTF8StringEncoding], @"& test failed");

    NSString *apostrophe = @"I'd";
    XCTAssertEqualObjects(@"I%27d", [apostrophe urlEncodedStringWithEncoding:NSUTF8StringEncoding], @"' test failed");

    NSString *openParen = @"(qrs";
    XCTAssertEqualObjects(@"%28qrs", [openParen urlEncodedStringWithEncoding:NSUTF8StringEncoding], @"( test failed");

    NSString *closeParen = @"tuv)";
    XCTAssertEqualObjects(@"tuv%29", [closeParen urlEncodedStringWithEncoding:NSUTF8StringEncoding], @") test failed");

    NSString *asterisk = @"sh*t";
    XCTAssertEqualObjects(@"sh%2At", [asterisk urlEncodedStringWithEncoding:NSUTF8StringEncoding], @"* test failed");

    NSString *plus = @"2+2";
    XCTAssertEqualObjects(@"2%2B2", [plus urlEncodedStringWithEncoding:NSUTF8StringEncoding], @"+ test failed");

    NSString *comma = @"x,y";
    XCTAssertEqualObjects(@"x%2Cy", [comma urlEncodedStringWithEncoding:NSUTF8StringEncoding], @", test failed");

    NSString *slash = @"x/y";
    XCTAssertEqualObjects(@"x%2Fy", [slash urlEncodedStringWithEncoding:NSUTF8StringEncoding], @"/ test failed");

    NSString *colon = @"4:00";
    XCTAssertEqualObjects(@"4%3A00", [colon urlEncodedStringWithEncoding:NSUTF8StringEncoding], @": test failed");

    NSString *semicolon = @"q;u";
    XCTAssertEqualObjects(@"q%3Bu", [semicolon urlEncodedStringWithEncoding:NSUTF8StringEncoding], @"; test failed");

    NSString *equal = @"5=6";
    XCTAssertEqualObjects(@"5%3D6", [equal urlEncodedStringWithEncoding:NSUTF8StringEncoding], @"= test failed");

    NSString *question = @"who?";
    XCTAssertEqualObjects(@"who%3F", [question urlEncodedStringWithEncoding:NSUTF8StringEncoding], @"? test failed");

    NSString *at = @"a@b";
    XCTAssertEqualObjects(@"a%40b", [at urlEncodedStringWithEncoding:NSUTF8StringEncoding], @"@ test failed");

    NSString *leftBracket = @"[a";
    XCTAssertEqualObjects(@"%5Ba", [leftBracket urlEncodedStringWithEncoding:NSUTF8StringEncoding], @"[ test failed");

    NSString *rightBracket = @"z]";
    XCTAssertEqualObjects(@"z%5D", [rightBracket urlEncodedStringWithEncoding:NSUTF8StringEncoding], @"] test failed");

    NSString *underscore = @"a_tag";
    XCTAssertEqualObjects(@"a_tag", [underscore urlEncodedStringWithEncoding:NSUTF8StringEncoding], @"_ test failed");

    NSString *snowman = @"☃";
    XCTAssertEqualObjects(@"%E2%98%83", [snowman urlEncodedStringWithEncoding:NSUTF8StringEncoding], @"snowman test failed");

    /**
     * %3C%7EBOu%21rD%5Dj7%3B%40%3C%3CW%2BF%21%2C%2B6Bl7Q%2BDf-%02ATD%3FH%7E%3E 
     * from Java's URLEncoder.encode("<~BOu!rD]j7;@<<W+F!,+6Bl7Q+Df-\2ATD?H~>", "UTF-8")
     */
    NSString *ascii85 = @"<~BOu!rD]j7;@<<W+F!,+6Bl7Q+Df-\2ATD?H~>";
    XCTAssertEqualObjects(@"%3C%7EBOu%21rD%5Dj7%3B%40%3C%3CW%2BF%21%2C%2B6Bl7Q%2BDf-%02ATD%3FH%7E%3E", [ascii85 urlEncodedStringWithEncoding:NSUTF8StringEncoding], @"ascii85 test failed");
}

- (void)testURLDecoding {

    NSString *simple = @"simple";
    XCTAssertEqualObjects(simple, [simple urlDecodedStringWithEncoding:NSUTF8StringEncoding], @"simple test failed");

    NSString *space = @"d%20e%20f";
    XCTAssertEqualObjects(@"d e f", [space urlDecodedStringWithEncoding:NSUTF8StringEncoding], @"space test failed");

    NSString *bang = @"go%21";
    XCTAssertEqualObjects(@"go!", [bang urlDecodedStringWithEncoding:NSUTF8StringEncoding], @"! test failed");

    NSString *quote = @"%22yes%22";
    XCTAssertEqualObjects(@"\"yes\"", [quote urlDecodedStringWithEncoding:NSUTF8StringEncoding], @"\" test failed");

    NSString *pound = @"xy%23z";
    XCTAssertEqualObjects(@"xy#z", [pound urlDecodedStringWithEncoding:NSUTF8StringEncoding], @"# test failed");

    NSString *dollar = @"%24100";
    XCTAssertEqualObjects(@"$100", [dollar urlDecodedStringWithEncoding:NSUTF8StringEncoding], @"$ test failed");

    NSString *percent = @"ab%25c";
    XCTAssertEqualObjects(@"ab%c", [percent urlDecodedStringWithEncoding:NSUTF8StringEncoding], @"percent test failed");

    NSString *ampersand = @"b%26w";
    XCTAssertEqualObjects(@"b&w", [ampersand urlDecodedStringWithEncoding:NSUTF8StringEncoding], @"& test failed");

    NSString *apostrophe = @"I%27d";
    XCTAssertEqualObjects(@"I'd", [apostrophe urlDecodedStringWithEncoding:NSUTF8StringEncoding], @"' test failed");

    NSString *openParen = @"%28qrs";
    XCTAssertEqualObjects(@"(qrs", [openParen urlDecodedStringWithEncoding:NSUTF8StringEncoding], @"( test failed");

    NSString *closeParen = @"tuv%29";
    XCTAssertEqualObjects(@"tuv)", [closeParen urlDecodedStringWithEncoding:NSUTF8StringEncoding], @") test failed");

    NSString *asterisk = @"sh%2At";
    XCTAssertEqualObjects(@"sh*t", [asterisk urlDecodedStringWithEncoding:NSUTF8StringEncoding], @"* test failed");

    NSString *plus = @"2%2B2";
    XCTAssertEqualObjects(@"2+2", [plus urlDecodedStringWithEncoding:NSUTF8StringEncoding], @"+ test failed");

    NSString *comma = @"x%2Cy";
    XCTAssertEqualObjects(@"x,y", [comma urlDecodedStringWithEncoding:NSUTF8StringEncoding], @", test failed");

    NSString *slash = @"x%2Fy";
    XCTAssertEqualObjects(@"x/y", [slash urlDecodedStringWithEncoding:NSUTF8StringEncoding], @"/ test failed");

    NSString *colon = @"4%3A00";
    XCTAssertEqualObjects(@"4:00", [colon urlDecodedStringWithEncoding:NSUTF8StringEncoding], @": test failed");

    NSString *semicolon = @"q%3Bu";
    XCTAssertEqualObjects(@"q;u", [semicolon urlDecodedStringWithEncoding:NSUTF8StringEncoding], @"; test failed");

    NSString *equal = @"5%3D6";
    XCTAssertEqualObjects(@"5=6", [equal urlDecodedStringWithEncoding:NSUTF8StringEncoding], @"= test failed");

    NSString *question = @"who%3F";
    XCTAssertEqualObjects(@"who?", [question urlDecodedStringWithEncoding:NSUTF8StringEncoding], @"? test failed");

    NSString *at = @"a%40b";
    XCTAssertEqualObjects(@"a@b", [at urlDecodedStringWithEncoding:NSUTF8StringEncoding], @"@ test failed");

    NSString *leftBracket = @"%5Ba";
    XCTAssertEqualObjects(@"[a", [leftBracket urlDecodedStringWithEncoding:NSUTF8StringEncoding], @"[ test failed");

    NSString *rightBracket = @"z%5D";
    XCTAssertEqualObjects(@"z]", [rightBracket urlDecodedStringWithEncoding:NSUTF8StringEncoding], @"] test failed");

    NSString *underscore = @"a_tag";
    XCTAssertEqualObjects(@"a_tag", [underscore urlDecodedStringWithEncoding:NSUTF8StringEncoding], @"_ test failed");

    NSString *snowman = @"%E2%98%83";
    XCTAssertEqualObjects(@"☃", [snowman urlDecodedStringWithEncoding:NSUTF8StringEncoding], @"snowman test failed");

    NSString *ascii85 = @"%3C%7EBOu%21rD%5Dj7%3B%40%3C%3CW%2BF%21%2C%2B6Bl7Q%2BDf-%02ATD%3FH%7E%3E";
    XCTAssertEqualObjects(@"<~BOu!rD]j7;@<<W+F!,+6Bl7Q+Df-\2ATD?H~>", [ascii85 urlDecodedStringWithEncoding:NSUTF8StringEncoding], @"ascii85 test failed");
}
@end
