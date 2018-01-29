/* Copyright 2018 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UAJSONMatcher.h"
#import "UAJSONValueMatcher.h"

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
