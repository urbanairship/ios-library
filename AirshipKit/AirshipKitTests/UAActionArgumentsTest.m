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
#import "UAActionArguments.h"
#import "UAActionArguments+Internal.h"

@interface UAActionArgumentsTest : XCTestCase

@end

@implementation UAActionArgumentsTest

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

/*
 * Test the argumentsWithValue:withSituation factory method sets the values correctly
 */
- (void)testArgumentsWithValue {
    UAActionArguments *args = [UAActionArguments argumentsWithValue:@"some-value" withSituation:UASituationBackgroundPush];
    XCTAssertEqualObjects(@"some-value", args.value, @"argumentsWithValue:withSituation: is not setting the value correctly");
    XCTAssertEqual(UASituationBackgroundPush, args.situation, @"argumentsWithValue:withSituation: is not setting the situation correctly");
}

/*
 * Test that the situations are correctly converted into string representations
 */
- (void)testSituationString {
    UAActionArguments *args = [UAActionArguments argumentsWithValue:@"whatever" withSituation:UASituationManualInvocation];
    XCTAssertEqualObjects(args.situationString, @"Manual Invocation", @"situation string should read 'Manual Invocation'");
    args.situation = UASituationBackgroundPush;
    XCTAssertEqualObjects(args.situationString, @"Background Push", @"situation string should read 'Background Push'");
    args.situation = UASituationForegroundPush;
    XCTAssertEqualObjects(args.situationString, @"Foreground Push", @"situation string should read 'Foreground Push'");
    args.situation = UASituationLaunchedFromPush;
    XCTAssertEqualObjects(args.situationString, @"Launched from Push", @"situation string should read 'Launched from Push'");
    args.situation = UASituationWebViewInvocation;
    XCTAssertEqualObjects(args.situationString, @"Webview Invocation", @"situation string should read 'Webview Invocation'");
    args.situation = UASituationForegroundInteractiveButton;
    XCTAssertEqualObjects(args.situationString, @"Foreground Interactive Button", @"situation string should read 'Foreground Interactive Button'");
    args.situation = UASituationBackgroundInteractiveButton;
    XCTAssertEqualObjects(args.situationString, @"Background Interactive Button", @"situation string should read 'Background Interactive Button'");
    args.situation = UASituationAutomation;
    XCTAssertEqualObjects(args.situationString, @"Automation", @"situation string should read 'Automation'");
    args.situation = 567;
    XCTAssertEqualObjects(args.situationString, @"Manual Invocation", @"situation string should read 'Manual Invocation'");
}

/*
 * Test the override of the description method
 */
- (void)testDescription {
    UAActionArguments *args = [UAActionArguments argumentsWithValue:@"foo" withSituation:UASituationManualInvocation];
    NSString *expectedDescription = [NSString stringWithFormat:@"UAActionArguments with situation: %@, value: %@",
                                     args.situationString, args.value];
    XCTAssertEqualObjects(args.description, expectedDescription, @"%@",[NSString stringWithFormat:@"description should read '%@'", expectedDescription]);
}

@end
