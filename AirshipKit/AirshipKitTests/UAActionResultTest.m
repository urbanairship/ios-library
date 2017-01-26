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
#import "UAActionResult.h"

@interface UAActionResultTest : XCTestCase

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
