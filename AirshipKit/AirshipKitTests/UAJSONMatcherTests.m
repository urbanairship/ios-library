/* Copyright 2010-2019 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UAJSONMatcher+Internal.h"
#import "UAJSONValueMatcher+Internal.h"

@interface UAJSONMatcherTests : UABaseTest
@property (nonatomic, strong) UAJSONValueMatcher *valueMatcher;
@end

@implementation UAJSONMatcherTests

- (void)setUp {
    [super setUp];

    self.valueMatcher = [UAJSONValueMatcher matcherWhereStringEquals:@"cool"];
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

- (void)testMatcherOnlyIgnoreCase {
    UAJSONMatcher *matcher = [UAJSONMatcher matcherWithValueMatcher:self.valueMatcher ignoreCase:YES];
    XCTAssertNotNil(matcher);
    XCTAssertTrue([matcher evaluateObject:@"cool"]);
    XCTAssertTrue([matcher evaluateObject:@"COOL"]);
    XCTAssertTrue([matcher evaluateObject:@"CooL"]);

    XCTAssertFalse([matcher evaluateObject:nil]);
    XCTAssertFalse([matcher evaluateObject:matcher]);
    XCTAssertFalse([matcher evaluateObject:@"not cool"]);
    XCTAssertFalse([matcher evaluateObject:@"NOT COOL"]);
    XCTAssertFalse([matcher evaluateObject:@{@"property": @"cool"}]);
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

- (void)testMatcherOnlyIgnoreCasePayload {
    NSDictionary *json = @{ @"value": @{ @"equals": @"cool" }, @"ignore_case":@(YES) };
    UAJSONMatcher *matcher = [UAJSONMatcher matcherWithValueMatcher:self.valueMatcher ignoreCase:YES];
    
    XCTAssertEqualObjects(json, matcher.payload);
    
    // Verify a matcher created from the JSON matches
    NSError *error = nil;
    UAJSONMatcher *matcherFromJSON = [UAJSONMatcher matcherWithJSON:json error:&error];
    XCTAssertNotNil(matcherFromJSON);
    XCTAssertEqualObjects(matcher, matcherFromJSON);
    XCTAssertNil(error);
    
    // Verify a matcher created from the JSON from the first matcher matches
    error = nil;
    matcherFromJSON = [UAJSONMatcher matcherWithJSON:[matcher payload] error:&error];
    XCTAssertNotNil(matcherFromJSON);
    XCTAssertEqualObjects(matcher, matcherFromJSON);
    XCTAssertNil(error);
}

- (void)testMatcherOnlyPayloadWithUnknownKey {
    NSDictionary *json = @{ @"value": @{ @"equals": @"cool" }, @"unknown": @(YES) };
    UAJSONMatcher *matcher = [UAJSONMatcher matcherWithValueMatcher:self.valueMatcher];
    XCTAssertNotNil(matcher);
    
    XCTAssertNotEqualObjects(json, matcher.payload);
    
    // Verify a matcher created from the JSON matches
    NSError *error = nil;
    UAJSONMatcher *matcherFromJSON = [UAJSONMatcher matcherWithJSON:json error:&error];
    XCTAssertNotNil(matcherFromJSON);
    XCTAssertEqualObjects(matcher, matcherFromJSON);
    XCTAssertNil(error);
    
    // Verify a matcher created from the JSON from the first matcher matches
    error = nil;
    matcherFromJSON = [UAJSONMatcher matcherWithJSON:[matcher payload] error:&error];
    XCTAssertNotNil(matcherFromJSON);
    XCTAssertEqualObjects(matcher, matcherFromJSON);
    XCTAssertNil(error);
    
}

- (void)testMatcherWithKey {
    UAJSONMatcher *matcher = [UAJSONMatcher matcherWithValueMatcher:self.valueMatcher scope:@[@"property"]];
    XCTAssertTrue([matcher evaluateObject:@{@"property": @"cool"}]);

    XCTAssertFalse([matcher evaluateObject:@"property"]);
    XCTAssertFalse([matcher evaluateObject:@{@"property": @"not cool"}]);
    XCTAssertFalse([matcher evaluateObject:nil]);
    XCTAssertFalse([matcher evaluateObject:matcher]);
    XCTAssertFalse([matcher evaluateObject:@"not cool"]);
    XCTAssertFalse([matcher evaluateObject:@(1)]);
    XCTAssertFalse([matcher evaluateObject:@(YES)]);
}

- (void)testMatcherWithScopeIgnoreCase {
    UAJSONMatcher *matcher = [UAJSONMatcher matcherWithValueMatcher:self.valueMatcher scope:@[@"property"] ignoreCase:YES];
    XCTAssertNotNil(matcher);
    XCTAssertTrue([matcher evaluateObject:@{@"property": @"cool"}]);
    XCTAssertTrue([matcher evaluateObject:@{@"property": @"COOL"}]);
    XCTAssertTrue([matcher evaluateObject:@{@"property": @"CooL"}]);
    
    XCTAssertFalse([matcher evaluateObject:@"property"]);
    XCTAssertFalse([matcher evaluateObject:@{@"property": @"not cool"}]);
    XCTAssertFalse([matcher evaluateObject:@{@"property": @"NOT COOL"}]);
    XCTAssertFalse([matcher evaluateObject:nil]);
    XCTAssertFalse([matcher evaluateObject:matcher]);
    XCTAssertFalse([matcher evaluateObject:@"not cool"]);
    XCTAssertFalse([matcher evaluateObject:@(1)]);
    XCTAssertFalse([matcher evaluateObject:@(YES)]);
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
    NSDictionary *json;

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
