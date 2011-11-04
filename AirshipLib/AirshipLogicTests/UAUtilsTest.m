/*
 Copyright 2009-2011 Urban Airship Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.
 
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

#import "UAUtils.h"
#import "UAUtilsTest.h"

@implementation UAUtilsTest

- (void)setUp
{
    [super setUp];
    
    // Set-up code here.
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}

- (void)testUrlEncoding
{
    /*
     * Should not encode simple strings
     */
    
    NSString* simple = @"simple";
    STAssertEqualObjects(simple, [UAUtils urlEncodedStringWithString:simple encoding:NSUTF8StringEncoding], @"simple test failed");
    
    /*
     * Should encode other characters
     */
    
    NSString* space = @"d e f";
    STAssertEqualObjects(@"d%20e%20f", [UAUtils urlEncodedStringWithString:space encoding:NSUTF8StringEncoding], @"space test failed");
    
    NSString* bang = @"go!";
    STAssertEqualObjects(@"go%21", [UAUtils urlEncodedStringWithString:bang encoding:NSUTF8StringEncoding], @"! test failed");
    
    NSString* quote = @"\"yes\"";
    STAssertEqualObjects(@"%22yes%22", [UAUtils urlEncodedStringWithString:quote encoding:NSUTF8StringEncoding], @"\" test failed");
    
    NSString* pound = @"xy#z";
    STAssertEqualObjects(@"xy%23z", [UAUtils urlEncodedStringWithString:pound encoding:NSUTF8StringEncoding], @"\" test failed");
    
    NSString* dollar = @"$100";
    STAssertEqualObjects(@"%24100", [UAUtils urlEncodedStringWithString:dollar encoding:NSUTF8StringEncoding], @"\" test failed");
    
    NSString* percent = @"ab%c";
    STAssertEqualObjects(@"ab%25c", [UAUtils urlEncodedStringWithString:percent encoding:NSUTF8StringEncoding], @"% test failed");
    
    NSString* ampersand = @"b&w";
    STAssertEqualObjects(@"b%26w", [UAUtils urlEncodedStringWithString:ampersand encoding:NSUTF8StringEncoding], @"& test failed");
    
    NSString* apostrophe = @"I'd";
    STAssertEqualObjects(@"I%27d", [UAUtils urlEncodedStringWithString:apostrophe encoding:NSUTF8StringEncoding], @"' test failed");
    
    NSString* openParen = @"(qrs";
    STAssertEqualObjects(@"%28qrs", [UAUtils urlEncodedStringWithString:openParen encoding:NSUTF8StringEncoding], @"( test failed");
    
    NSString* closeParen = @"tuv)";
    STAssertEqualObjects(@"tuv%29", [UAUtils urlEncodedStringWithString:closeParen encoding:NSUTF8StringEncoding], @") test failed");
    
    NSString* asterisk = @"sh*t";
    STAssertEqualObjects(@"sh%2At", [UAUtils urlEncodedStringWithString:asterisk encoding:NSUTF8StringEncoding], @"* test failed");
    
    NSString* plus = @"2+2";
    STAssertEqualObjects(@"2%2B2", [UAUtils urlEncodedStringWithString:plus encoding:NSUTF8StringEncoding], @"+ test failed");
    
    NSString* comma = @"x,y";
    STAssertEqualObjects(@"x%2Cy", [UAUtils urlEncodedStringWithString:comma encoding:NSUTF8StringEncoding], @", test failed");
    
    NSString* slash = @"x/y";
    STAssertEqualObjects(@"x%2Fy", [UAUtils urlEncodedStringWithString:slash encoding:NSUTF8StringEncoding], @"/ test failed");
    
    NSString* colon = @"4:00";
    STAssertEqualObjects(@"4%3A00", [UAUtils urlEncodedStringWithString:colon encoding:NSUTF8StringEncoding], @": test failed");
    
    NSString* semicolon = @"q;u";
    STAssertEqualObjects(@"q%3Bu", [UAUtils urlEncodedStringWithString:semicolon encoding:NSUTF8StringEncoding], @"; test failed");
    
    NSString* equal = @"5=6";
    STAssertEqualObjects(@"5%3D6", [UAUtils urlEncodedStringWithString:equal encoding:NSUTF8StringEncoding], @"= test failed");
    
    NSString* question = @"who?";
    STAssertEqualObjects(@"who%3F", [UAUtils urlEncodedStringWithString:question encoding:NSUTF8StringEncoding], @"? test failed");
    
    NSString* at = @"a@b";
    STAssertEqualObjects(@"a%40b", [UAUtils urlEncodedStringWithString:at encoding:NSUTF8StringEncoding], @"@ test failed");
    
    NSString* leftBracket = @"[a";
    STAssertEqualObjects(@"%5Ba", [UAUtils urlEncodedStringWithString:leftBracket encoding:NSUTF8StringEncoding], @"[ test failed");
    
    NSString* rightBracket = @"z]";
    STAssertEqualObjects(@"z%5D", [UAUtils urlEncodedStringWithString:rightBracket encoding:NSUTF8StringEncoding], @"] test failed");
}

@end
