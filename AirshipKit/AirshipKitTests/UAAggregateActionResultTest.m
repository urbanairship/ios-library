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
#import "UAAggregateActionResult.h"

@interface UAAggregateActionResultTest : XCTestCase

@end

@implementation UAAggregateActionResultTest


/**
 * Test adding other UAActionResults to an aggregate result
 */
- (void)testAddResult {
    UAAggregateActionResult *aggregateResult = [[UAAggregateActionResult alloc] init];
    UAActionResult *result = [UAActionResult emptyResult];
    UAActionResult *anotherResult = [UAActionResult emptyResult];

    [aggregateResult addResult:result forAction:@"actionName"];
    [aggregateResult addResult:anotherResult forAction:@"anotherActionName"];

    NSDictionary *value = aggregateResult.value;
    XCTAssertEqual((NSUInteger) 2, value.count, @"adding a result should add it to the aggregate action's value");
    XCTAssertEqualObjects([value valueForKey:@"actionName"], result, @"adding a result should add it to the aggregate action's value");
    XCTAssertEqualObjects([value valueForKey:@"anotherActionName"], anotherResult, @"adding a result should add it to the aggregate action's value");
}

/**
 * Test retrieving the result for a particular action
 */
- (void)testResultForAction {
    UAAggregateActionResult *aggregateResult = [[UAAggregateActionResult alloc] init];
    UAActionResult *result = [UAActionResult emptyResult];
    UAActionResult *anotherResult = [UAActionResult emptyResult];

    [aggregateResult addResult:result forAction:@"actionName"];
    [aggregateResult addResult:anotherResult forAction:@"anotherActionName"];

    XCTAssertEqualObjects([aggregateResult resultForAction:@"actionName"], result, @"result for action is not returning correct result");
    XCTAssertEqualObjects([aggregateResult resultForAction:@"anotherActionName"], anotherResult, @"result for action is not returning correct result");
}

/**
 * Test merging fetch completion values
 */
- (void)testMergeFetchCompletionValue {
    UAAggregateActionResult *aggregateResult = [[UAAggregateActionResult alloc] init];
    XCTAssertEqual(aggregateResult.fetchResult, UAActionFetchResultNoData, @"fetch result should default to UAActionFetchResultNoData");

    // Add UAActionFetchResultNoData, should be UAActionFetchResultNoData
    [aggregateResult addResult:[UAActionResult resultWithValue:nil withFetchResult:UAActionFetchResultNoData] forAction:@"action"];
    XCTAssertEqual(aggregateResult.fetchResult, UAActionFetchResultNoData, @"merging UAActionFetchResultNoData with UAActionFetchResultNoData should still be UAActionFetchResultNoData");

    // Add UAActionFetchResultFailed, should be UAActionFetchResultFailed
    [aggregateResult addResult:[UAActionResult resultWithValue:nil withFetchResult:UAActionFetchResultFailed] forAction:@"action"];
    XCTAssertEqual(aggregateResult.fetchResult, UAActionFetchResultFailed, @"merging UAActionFetchResultNoData with UAActionFetchResultFailed should be UAActionFetchResultFailed");

    // Add UAActionFetchResultNoData, should be UAActionFetchResultFailed
    [aggregateResult addResult:[UAActionResult resultWithValue:nil withFetchResult:UAActionFetchResultNoData] forAction:@"action"];
    XCTAssertEqual(aggregateResult.fetchResult, UAActionFetchResultFailed, @"merging UAActionFetchResultFailed with UAActionFetchResultNoData should be UAActionFetchResultFailed");

    // Add UAActionFetchResultNewData, should be UAActionFetchResultNewData
    [aggregateResult addResult:[UAActionResult resultWithValue:nil withFetchResult:UAActionFetchResultNewData] forAction:@"action"];
    XCTAssertEqual(aggregateResult.fetchResult, UAActionFetchResultNewData, @"merging UAActionFetchResultFailed with UAActionFetchResultNewData should be UAActionFetchResultNewData");

    // Add UAActionFetchResultFailed, should be UAActionFetchResultNewData
    [aggregateResult addResult:[UAActionResult resultWithValue:nil withFetchResult:UAActionFetchResultFailed] forAction:@"action"];
    XCTAssertEqual(aggregateResult.fetchResult, UAActionFetchResultNewData, @"merging UAActionFetchResultNewData with UAActionFetchResultFailed should be UAActionFetchResultNewData");

    // Add UAActionFetchResultNoData, should be UAActionFetchResultNewData
    [aggregateResult addResult:[UAActionResult resultWithValue:nil withFetchResult:UAActionFetchResultNoData] forAction:@"action"];
    XCTAssertEqual(aggregateResult.fetchResult, UAActionFetchResultNewData, @"merging UAActionFetchResultNewData with UAActionFetchResultNoData should be UAActionFetchResultNewData");
}

@end
