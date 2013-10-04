/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
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

@interface UAActionArgumentsTest : XCTestCase

@end

@implementation UAActionArgumentsTest

- (void)setUp {
    [super setUp];

    // Clear arguments before a test runs
    [UAActionArguments clearSpringBoardActionArguments];
}

- (void)tearDown {

    // Clear arguments to avoid polluting other tests
    [UAActionArguments clearSpringBoardActionArguments];
    [super tearDown];
}

/*
 * Test the argumntesWithValue:withSituation factory method sets the values correctly
 */
- (void)testArgumentsWithValue {
    UAActionArguments *args = [UAActionArguments argumentsWithValue:@"some-value" withSituation:@"some-situation"];
    XCTAssertEqualObjects(@"some-value", args.value, @"argumentsWithValue:withSituation: is not setting the value correctly");
    XCTAssertEqualObjects(@"some-situation", args.situation, @"argumentsWithValue:withSituation: is not setting the situation correctly");
}

/*
 * Test pending spring board action arguments creates an empty dictionary
 * if no arguments exists
 */
- (void)testPendingSpringBoardActionArgumentsNoArgs {
    NSDictionary *args = [UAActionArguments pendingSpringBoardPushActionArguments];
    XCTAssertNotNil(args, @"Empty pending arguments should still return an empty dictionary");
    XCTAssertEqual((NSUInteger)0, args.count, @"Empty pending arguments should resullt in an empty dictionary");
}

/*
 * Test add pending spring board actions
 */
- (void)testAddPendingSpringBoardAction {
    [UAActionArguments addPendingSpringBoardAction:@"action" value:@"action-value"];
    [UAActionArguments addPendingSpringBoardAction:@"another-action" value:@"another-action-value"];

    NSDictionary *args = [UAActionArguments pendingSpringBoardPushActionArguments];
    XCTAssertEqual((NSUInteger)2, args.count, @"Empty pending arguments should resullt in an empty dictionary");

    // Validate the first argument
    UAActionArguments *actionArgument = [args valueForKey:@"action"];
    XCTAssertEqual(actionArgument.value, @"action-value", @"Action argument is not mapped to correct value");
    XCTAssertEqual(actionArgument.situation, UASituationLaunchedFromSpringBoard, @"All pending spring board arguments should have UASituationLaunchedFromSpringBoard situation");

    // Validate the second argument
    UAActionArguments *anotherActionArgument = [args valueForKey:@"another-action"];
    XCTAssertEqual(anotherActionArgument.value, @"another-action-value", @"Action argument is not mapped to correct value");
    XCTAssertEqual(anotherActionArgument.situation, UASituationLaunchedFromSpringBoard, @"All pending spring board arguments should have UASituationLaunchedFromSpringBoard situation");
}

/*
 * Test remove pending spring board actions
 */
- (void)testRemovePendingSpringBoardAction {
    // Add two
    [UAActionArguments addPendingSpringBoardAction:@"action" value:@"action-value"];
    [UAActionArguments addPendingSpringBoardAction:@"another-action" value:@"another-action-value"];

    // Remove one
    [UAActionArguments removePendingSpringBoardAction:@"action"];

    NSDictionary *args = [UAActionArguments pendingSpringBoardPushActionArguments];
    XCTAssertEqual((NSUInteger)1, args.count, @"Empty pending arguments should resullt in an empty dictionary");

    // Validate the second argument is still present
    UAActionArguments *anotherActionArgument = [args valueForKey:@"another-action"];
    XCTAssertEqual(anotherActionArgument.value, @"another-action-value", @"Action argument is not mapped to correct value");
    XCTAssertEqual(anotherActionArgument.situation, UASituationLaunchedFromSpringBoard, @"All pending spring board arguments should have UASituationLaunchedFromSpringBoard situation");
}

/*
 * Test clear pending spring board actions
 */
- (void)testClearSpringBoardActionArguments {
    // Add two
    [UAActionArguments addPendingSpringBoardAction:@"action" value:@"action-value"];
    [UAActionArguments addPendingSpringBoardAction:@"another-action" value:@"another-action-value"];

    [UAActionArguments clearSpringBoardActionArguments];

    // Clear it
    NSDictionary *args = [UAActionArguments pendingSpringBoardPushActionArguments];
    XCTAssertEqual((NSUInteger)0, args.count, @"Clear spring board actions is not clearing all the arguments");

}

@end
