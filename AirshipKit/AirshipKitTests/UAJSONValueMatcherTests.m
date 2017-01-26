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
#import "UAJSONValueMatcher.h"

@interface UAJSONValueMatcherTests : XCTestCase

@end

@implementation UAJSONValueMatcherTests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testEqualsString {
    UAJSONValueMatcher *matcher = [UAJSONValueMatcher matcherWhereStringEquals:@"cool"];
    XCTAssertTrue([matcher evaluateObject:@"cool"]);

    XCTAssertFalse([matcher evaluateObject:nil]);
    XCTAssertFalse([matcher evaluateObject:matcher]);
    XCTAssertFalse([matcher evaluateObject:@"not cool"]);
    XCTAssertFalse([matcher evaluateObject:@(1)]);
    XCTAssertFalse([matcher evaluateObject:@(YES)]);
}

- (void)testEqualsStringPayload {
    NSDictionary *json = @{ @"equals": @"cool" };
    UAJSONValueMatcher *matcher = [UAJSONValueMatcher matcherWhereStringEquals:@"cool"];

    XCTAssertEqualObjects(json, matcher.payload);

    // Verify the JSONValue recreates the expected payload
    NSError *error = nil;
    XCTAssertEqualObjects(json, [UAJSONValueMatcher matcherWithJSON:json error:&error].payload);
    XCTAssertNil(error);
}

- (void)testEqualsNumber {
    UAJSONValueMatcher *matcher = [UAJSONValueMatcher matcherWhereNumberEquals:@(123.35)];
    XCTAssertTrue([matcher evaluateObject:@(123.35)]);
    XCTAssertTrue([matcher evaluateObject:@(123.350)]);

    XCTAssertFalse([matcher evaluateObject:nil]);
    XCTAssertFalse([matcher evaluateObject:matcher]);
    XCTAssertFalse([matcher evaluateObject:@"not cool"]);
    XCTAssertFalse([matcher evaluateObject:@(123)]);
    XCTAssertFalse([matcher evaluateObject:@(123.3)]);
    XCTAssertFalse([matcher evaluateObject:@(YES)]);
}

- (void)testEqualsNumberPayload {
    NSDictionary *json = @{ @"equals": @(123.456) };
    UAJSONValueMatcher *matcher = [UAJSONValueMatcher matcherWhereNumberEquals:@(123.456)];

    XCTAssertEqualObjects(json, matcher.payload);

    // Verify the JSONValue recreates the expected payload
    NSError *error = nil;
    XCTAssertEqualObjects(json, [UAJSONValueMatcher matcherWithJSON:json error:&error].payload);
    XCTAssertNil(error);
}

- (void)testAtLeast {
    UAJSONValueMatcher *matcher = [UAJSONValueMatcher matcherWhereNumberAtLeast:@(123.35)];
    XCTAssertTrue([matcher evaluateObject:@(123.35)]);
    XCTAssertTrue([matcher evaluateObject:@(123.36)]);

    XCTAssertFalse([matcher evaluateObject:nil]);
    XCTAssertFalse([matcher evaluateObject:matcher]);
    XCTAssertFalse([matcher evaluateObject:@"not cool"]);
    XCTAssertFalse([matcher evaluateObject:@(123)]);
    XCTAssertFalse([matcher evaluateObject:@(123.3)]);
    XCTAssertFalse([matcher evaluateObject:@(YES)]);
}

- (void)testAtLeastPayload {
    NSDictionary *json = @{ @"at_least": @(100) };
    UAJSONValueMatcher *matcher = [UAJSONValueMatcher matcherWhereNumberAtLeast:@(100)];

    XCTAssertEqualObjects(json, matcher.payload);

    // Verify the JSONValue recreates the expected payload
    NSError *error = nil;
    XCTAssertEqualObjects(json, [UAJSONValueMatcher matcherWithJSON:json error:&error].payload);
    XCTAssertNil(error);
}

- (void)testAtMost {
    UAJSONValueMatcher *matcher = [UAJSONValueMatcher matcherWhereNumberAtMost:@(123.35)];
    XCTAssertTrue([matcher evaluateObject:@(123.35)]);
    XCTAssertTrue([matcher evaluateObject:@(123.34)]);

    XCTAssertFalse([matcher evaluateObject:nil]);
    XCTAssertFalse([matcher evaluateObject:matcher]);
    XCTAssertFalse([matcher evaluateObject:@"not cool"]);
    XCTAssertFalse([matcher evaluateObject:@(123.36)]);
    XCTAssertFalse([matcher evaluateObject:@(124)]);
}

- (void)testAtMostPayload {
    NSDictionary *json = @{ @"at_most": @(100) };
    UAJSONValueMatcher *matcher = [UAJSONValueMatcher matcherWhereNumberAtMost:@(100)];

    XCTAssertEqualObjects(json, matcher.payload);

    // Verify the JSONValue recreates the expected payload
    NSError *error = nil;
    XCTAssertEqualObjects(json, [UAJSONValueMatcher matcherWithJSON:json error:&error].payload);
    XCTAssertNil(error);
}

- (void)testAtLeastAtMost {
    UAJSONValueMatcher *matcher = [UAJSONValueMatcher matcherWhereNumberAtLeast:@(100) atMost:@(150)];
    XCTAssertTrue([matcher evaluateObject:@(100)]);
    XCTAssertTrue([matcher evaluateObject:@(150)]);
    XCTAssertTrue([matcher evaluateObject:@(123.456)]);

    XCTAssertFalse([matcher evaluateObject:nil]);
    XCTAssertFalse([matcher evaluateObject:matcher]);
    XCTAssertFalse([matcher evaluateObject:@"not cool"]);
    XCTAssertFalse([matcher evaluateObject:@(99)]);
    XCTAssertFalse([matcher evaluateObject:@(151)]);
}

- (void)testAtLeastAtMostPayload {
    NSDictionary *json = @{ @"at_least": @(1), @"at_most": @(100) };
    UAJSONValueMatcher *matcher = [UAJSONValueMatcher matcherWhereNumberAtLeast:@(1) atMost:@(100)];

    XCTAssertEqualObjects(json, matcher.payload);

    // Verify the JSONValue recreates the expected payload
    NSError *error = nil;
    XCTAssertEqualObjects(json, [UAJSONValueMatcher matcherWithJSON:json error:&error].payload);
    XCTAssertNil(error);
}

- (void)testPresence {
    UAJSONValueMatcher *matcher = [UAJSONValueMatcher matcherWhereValueIsPresent:YES];
    XCTAssertTrue([matcher evaluateObject:@(100)]);
    XCTAssertTrue([matcher evaluateObject:matcher]);
    XCTAssertTrue([matcher evaluateObject:@"cool"]);

    XCTAssertFalse([matcher evaluateObject:nil]);
}

- (void)testPresencePayload {
    NSDictionary *json = @{ @"is_present": @(YES) };
    UAJSONValueMatcher *matcher = [UAJSONValueMatcher matcherWhereValueIsPresent:YES];

    XCTAssertEqualObjects(json, matcher.payload);

    // Verify the JSONValue recreates the expected payload
    NSError *error = nil;
    XCTAssertEqualObjects(json, [UAJSONValueMatcher matcherWithJSON:json error:&error].payload);
    XCTAssertNil(error);
}

- (void)testAbsence {
    UAJSONValueMatcher *matcher = [UAJSONValueMatcher matcherWhereValueIsPresent:NO];
    XCTAssertTrue([matcher evaluateObject:nil]);

    XCTAssertFalse([matcher evaluateObject:@(100)]);
    XCTAssertFalse([matcher evaluateObject:matcher]);
    XCTAssertFalse([matcher evaluateObject:@"cool"]);
}

- (void)testAbsencePayload {
    NSDictionary *json = @{ @"is_present": @(NO) };
    UAJSONValueMatcher *matcher = [UAJSONValueMatcher matcherWhereValueIsPresent:NO];

    XCTAssertEqualObjects(json, matcher.payload);

    // Verify the JSONValue recreates the expected payload
    NSError *error = nil;
    XCTAssertEqualObjects(json, [UAJSONValueMatcher matcherWithJSON:json error:&error].payload);
    XCTAssertNil(error);
}

- (void)testInvalidPayload {

    // Invalid combo
    NSError *error;
    NSDictionary *json = @{ @"is_present": @(NO), @"equals": @(100) };
    XCTAssertNil([UAJSONValueMatcher matcherWithJSON:json error:&error]);
    XCTAssertNotNil(error);

    // Unknown key
    json = @{ @"is_present": @(NO), @"what": @(100) };
    error = nil;
    XCTAssertNil([UAJSONValueMatcher matcherWithJSON:json error:&error]);
    XCTAssertNotNil(error);

    // Invalid is_present value
    json = @{ @"is_present": @"cool story" };
    error = nil;
    XCTAssertNil([UAJSONValueMatcher matcherWithJSON:json error:&error]);
    XCTAssertNotNil(error);

    // Invalid at_least value
    json = @{ @"at_least": @"cool story" };
    error = nil;
    XCTAssertNil([UAJSONValueMatcher matcherWithJSON:json error:&error]);
    XCTAssertNotNil(error);

    // Invalid at_most value
    json = @{ @"at_most": @"cool story" };
    error = nil;
    XCTAssertNil([UAJSONValueMatcher matcherWithJSON:json error:&error]);
    XCTAssertNotNil(error);

    // Invalid equals value
    json = @{ @"equals": @[] };
    error = nil;
    XCTAssertNil([UAJSONValueMatcher matcherWithJSON:json error:&error]);
    XCTAssertNotNil(error);

    // Invalid object
    error = nil;
    XCTAssertNil([UAJSONValueMatcher matcherWithJSON:@"cool" error:&error]);
    XCTAssertNotNil(error);
}

@end
