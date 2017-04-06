/* Copyright 2017 Urban Airship and Contributors */

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
