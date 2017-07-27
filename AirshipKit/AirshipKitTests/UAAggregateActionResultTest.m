/* Copyright 2017 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UAAggregateActionResult.h"

@interface UAAggregateActionResultTest : UABaseTest

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
