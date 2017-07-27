/* Copyright 2017 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UAActionResult.h"

@interface UAActionResultTest : UABaseTest

@end

@implementation UAActionResultTest

/*
 * Test the resultWithValue: factory method
 */
- (void)testResultWithValue {
    UAActionResult *result = [UAActionResult resultWithValue:@"some-value"];

    XCTAssertEqualObjects(@"some-value", result.value, @"Result value is not being set correctly");
    XCTAssertEqual(UAActionFetchResultNoData, result.fetchResult, @"Fetch result should default UAActionFetchResultNoData");
    XCTAssertNil(result.error, @"resultWithValue should create a result with a nil error");
}

/*
 * Test the resultWithValue:withFetchResult: factory method
 */
- (void)testResultWithValueWithFetchResult {
    UAActionResult *result = [UAActionResult resultWithValue:@"some-value" withFetchResult:UAActionFetchResultNewData];

    XCTAssertEqualObjects(@"some-value", result.value, @"Result's value is not being set correctly");
    XCTAssertEqual(UAActionFetchResultNewData, result.fetchResult, @"Fetch result not being set correctly");
    XCTAssertNil(result.error, @"resultWithValue should create a result with a nil error");
}

/*
 * Test the none factory method
 */
- (void)testNone {
    UAActionResult *result = [UAActionResult emptyResult];

    XCTAssertNil(result.error, @"none should create a result with a nil error");
    XCTAssertNil(result.value, @"none should create a result with a nil value");
    XCTAssertEqual(UAActionFetchResultNoData, result.fetchResult, @"Fetch result should default UAActionFetchResultNoData");
}

/*
 * Test the error: factory method
 */
- (void)testError {
    NSError *error = [NSError errorWithDomain:@"some-domain" code:200 userInfo:nil];
    UAActionResult *result = [UAActionResult resultWithError:error];

    XCTAssertEqualObjects(error, result.error, @"Result's error is not being set correctly");
    XCTAssertNil(result.value, @"error should create a result with a nil value");
    XCTAssertEqual(UAActionFetchResultNoData, result.fetchResult, @"Results fetch result should default UAActionFetchResultNoData");
}

@end
