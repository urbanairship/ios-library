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
#import "UAJSONMatcher.h"
#import "UAJSONValueMatcher.h"

@interface UAJSONMatcherTests : XCTestCase
@property (nonatomic, strong) UAJSONValueMatcher *valueMatcher;
@end

@implementation UAJSONMatcherTests

- (void)setUp {
    [super setUp];

    self.valueMatcher = [UAJSONValueMatcher matcherWhereStringEquals:@"cool"];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testMatcherOnly {
    UAJSONMatcher *matcher = [UAJSONMatcher matcherWithValueMatcher:self.valueMatcher];
    XCTAssertTrue([matcher evaluateObject:@"cool"]);

    XCTAssertFalse([matcher evaluateObject:nil]);
    XCTAssertFalse([matcher evaluateObject:matcher]);
    XCTAssertFalse([matcher evaluateObject:@"not cool"]);
    XCTAssertFalse([matcher evaluateObject:@(1)]);
    XCTAssertFalse([matcher evaluateObject:@(YES)]);
}

- (void)testMatcherOnlyPayload {
    NSDictionary *json = @{ @"value": @{ @"equals": @"cool" } };
    UAJSONMatcher *matcher = [UAJSONMatcher matcherWithValueMatcher:self.valueMatcher];

    XCTAssertEqualObjects(json, matcher.payload);

    // Verify the JSONValue recreates the expected payload
    NSError *error = nil;
    XCTAssertEqualObjects(json, [UAJSONMatcher matcherWithJSON:json error:&error].payload);
    XCTAssertNil(error);
}

- (void)testMatcherWithKey {
    UAJSONMatcher *matcher = [UAJSONMatcher matcherWithValueMatcher:self.valueMatcher key:@"property"];
    XCTAssertTrue([matcher evaluateObject:@{@"property": @"cool"}]);

    XCTAssertFalse([matcher evaluateObject:@"property"]);
    XCTAssertFalse([matcher evaluateObject:@{@"property": @"not cool"}]);
    XCTAssertFalse([matcher evaluateObject:nil]);
    XCTAssertFalse([matcher evaluateObject:matcher]);
    XCTAssertFalse([matcher evaluateObject:@"not cool"]);
    XCTAssertFalse([matcher evaluateObject:@(1)]);
    XCTAssertFalse([matcher evaluateObject:@(YES)]);
}

- (void)testMatcherWithKeyPayload {
    NSDictionary *json = @{ @"value": @{ @"equals": @"cool" }, @"key": @"property" };
    UAJSONMatcher *matcher = [UAJSONMatcher matcherWithValueMatcher:self.valueMatcher key:@"property"];

    XCTAssertEqualObjects(json, matcher.payload);

    // Verify the JSONValue recreates the expected payload
    NSError *error = nil;
    XCTAssertEqualObjects(json, [UAJSONMatcher matcherWithJSON:json error:&error].payload);
    XCTAssertNil(error);
}

- (void)testMatcherWithKeyAndScope {
    UAJSONMatcher *matcher = [UAJSONMatcher matcherWithValueMatcher:self.valueMatcher
                                                                key:@"subproperty"
                                                              scope:@[@"property"]];

    XCTAssertTrue([matcher evaluateObject:@{@"property": @{ @"subproperty": @"cool"}}]);

    XCTAssertFalse([matcher evaluateObject:@"property"]);
    XCTAssertFalse([matcher evaluateObject:@{@"property": @"subproperty"}]);
    XCTAssertFalse([matcher evaluateObject:@{@"property": @{ @"subproperty": @"not cool"}}]);

    XCTAssertFalse([matcher evaluateObject:nil]);
    XCTAssertFalse([matcher evaluateObject:matcher]);
    XCTAssertFalse([matcher evaluateObject:@"not cool"]);
    XCTAssertFalse([matcher evaluateObject:@(1)]);
    XCTAssertFalse([matcher evaluateObject:@(YES)]);
}

- (void)testMatcherWithKeyAndScopePayload {
    NSDictionary *json = @{ @"value": @{ @"equals": @"cool" }, @"key": @"subproperty", @"scope": @[@"property"] };
    UAJSONMatcher *matcher = [UAJSONMatcher matcherWithValueMatcher:self.valueMatcher
                                                                key:@"subproperty"
                                                              scope:@[@"property"]];
    XCTAssertEqualObjects(json, matcher.payload);

    // Verify the JSONValue recreates the expected payload
    NSError *error = nil;
    XCTAssertEqualObjects(json, [UAJSONMatcher matcherWithJSON:json error:&error].payload);
    XCTAssertNil(error);
}

- (void)testScopeAsString {
    // Should convert it back to an array
    NSDictionary *expectedPayload = @{ @"value": @{ @"equals": @"cool" }, @"key": @"subproperty", @"scope": @[@"property"] };
    NSDictionary *json = @{ @"value": @{ @"equals": @"cool" }, @"key": @"subproperty", @"scope": @"property" };

    NSError *error = nil;
    XCTAssertEqualObjects(expectedPayload, [UAJSONMatcher matcherWithJSON:json error:&error].payload);
    XCTAssertNil(error);
}

- (void)testInvalidPayload {
    NSError *error;

    // Unknown key
    NSDictionary *json = @{ @"value": @{ @"equals": @"cool" }, @"what": @(100) };
    XCTAssertNil([UAJSONMatcher matcherWithJSON:json error:&error]);
    XCTAssertNotNil(error);

    // Invalid key value
    error = nil;
    json = @{ @"value": @{ @"equals": @"cool" }, @"key": @(123), @"scope": @[@"property"] };
    XCTAssertNil([UAJSONMatcher matcherWithJSON:json error:&error]);
    XCTAssertNotNil(error);

    // Invalid scope value
    error = nil;
    json = @{ @"value": @{ @"equals": @"cool" }, @"key": @"cool", @"scope": @{} };
    XCTAssertNil([UAJSONMatcher matcherWithJSON:json error:&error]);
    XCTAssertNotNil(error);

    // Invalid object
    error = nil;
    XCTAssertNil([UAJSONMatcher matcherWithJSON:@"not cool" error:&error]);
    XCTAssertNotNil(error);
}


@end
