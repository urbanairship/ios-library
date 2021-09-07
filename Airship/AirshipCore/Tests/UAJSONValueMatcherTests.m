/* Copyright Airship and Contributors */

#import "UABaseTest.h"

@import AirshipCore;

@interface UAJSONValueMatcherTests : UABaseTest

@end

@implementation UAJSONValueMatcherTests


- (void)testEqualsString {
    UAJSONValueMatcher *matcher = [UAJSONValueMatcher matcherWhereStringEquals:@"cool"];
    XCTAssertTrue([matcher evaluateObject:@"cool"]);
    XCTAssertTrue([matcher evaluateObject:@"cool" ignoreCase:NO]);
    XCTAssertTrue([matcher evaluateObject:@"cool" ignoreCase:YES]);
    XCTAssertTrue([matcher evaluateObject:@"COOL" ignoreCase:YES]);
    XCTAssertTrue([matcher evaluateObject:@"CooL" ignoreCase:YES]);

    XCTAssertFalse([matcher evaluateObject:nil]);
    XCTAssertFalse([matcher evaluateObject:matcher]);
    XCTAssertFalse([matcher evaluateObject:@"COOL"]);
    XCTAssertFalse([matcher evaluateObject:@"CooL"]);
    XCTAssertFalse([matcher evaluateObject:@"NOT COOL"]);
    XCTAssertFalse([matcher evaluateObject:@"not cool"]);
    XCTAssertFalse([matcher evaluateObject:@(1)]);
    XCTAssertFalse([matcher evaluateObject:@(YES)]);

    XCTAssertFalse([matcher evaluateObject:nil ignoreCase:NO]);
    XCTAssertFalse([matcher evaluateObject:matcher ignoreCase:NO]);
    XCTAssertFalse([matcher evaluateObject:@"COOL" ignoreCase:NO]);
    XCTAssertFalse([matcher evaluateObject:@"CooL" ignoreCase:NO]);
    XCTAssertFalse([matcher evaluateObject:@"NOT COOL" ignoreCase:NO]);
    XCTAssertFalse([matcher evaluateObject:@"not cool" ignoreCase:NO]);
    XCTAssertFalse([matcher evaluateObject:@(1) ignoreCase:NO]);
    XCTAssertFalse([matcher evaluateObject:@(YES) ignoreCase:NO]);

    XCTAssertFalse([matcher evaluateObject:nil ignoreCase:YES]);
    XCTAssertFalse([matcher evaluateObject:matcher ignoreCase:YES]);
    XCTAssertFalse([matcher evaluateObject:@"NOT COOL" ignoreCase:YES]);
    XCTAssertFalse([matcher evaluateObject:@"not cool" ignoreCase:YES]);
    XCTAssertFalse([matcher evaluateObject:@(1) ignoreCase:YES]);
    XCTAssertFalse([matcher evaluateObject:@(YES) ignoreCase:YES]);
}

- (void)testEqualsStringPayload {
    NSDictionary *json = @{ @"equals": @"cool" };
    UAJSONValueMatcher *matcher = [UAJSONValueMatcher matcherWhereStringEquals:@"cool"];

    // Verify the JSONValue recreates the expected matcher
    NSError *error = nil;
    XCTAssertEqualObjects(matcher, [UAJSONValueMatcher matcherWithJSON:json error:&error]);
    XCTAssertNil(error);
}

- (void)testEqualsBoolean {
    UAJSONValueMatcher *matcher = [UAJSONValueMatcher matcherWhereBooleanEquals:NO];
    XCTAssertTrue([matcher evaluateObject:@(NO)]);
    XCTAssertTrue([matcher evaluateObject:@(NO) ignoreCase:YES]);
    XCTAssertTrue([matcher evaluateObject:@(NO) ignoreCase:NO]);

    XCTAssertFalse([matcher evaluateObject:nil]);
    XCTAssertFalse([matcher evaluateObject:matcher]);
    XCTAssertFalse([matcher evaluateObject:@"not cool"]);
    XCTAssertFalse([matcher evaluateObject:@(1)]);
    XCTAssertFalse([matcher evaluateObject:@(YES)]);
    XCTAssertFalse([matcher evaluateObject:@(YES) ignoreCase:YES]);
    XCTAssertFalse([matcher evaluateObject:@(YES) ignoreCase:NO]);
}

- (void)testEqualsBooleanPayload {
    NSDictionary *json = @{ @"equals": @(YES) };
    UAJSONValueMatcher *matcher = [UAJSONValueMatcher matcherWhereBooleanEquals:YES];

    // Verify the JSONValue recreates the expected matcher
    NSError *error = nil;
    XCTAssertEqualObjects(matcher, [UAJSONValueMatcher matcherWithJSON:json error:&error]);
    XCTAssertNil(error);
}


- (void)testEqualsNumber {
    UAJSONValueMatcher *matcher = [UAJSONValueMatcher matcherWhereNumberEquals:@(123.35)];
    XCTAssertTrue([matcher evaluateObject:@(123.35)]);
    XCTAssertTrue([matcher evaluateObject:@(123.350)]);
    XCTAssertTrue([matcher evaluateObject:@(123.350) ignoreCase:YES]);
    XCTAssertTrue([matcher evaluateObject:@(123.350) ignoreCase:NO]);

    XCTAssertFalse([matcher evaluateObject:nil]);
    XCTAssertFalse([matcher evaluateObject:matcher]);
    XCTAssertFalse([matcher evaluateObject:@"not cool"]);
    XCTAssertFalse([matcher evaluateObject:@(123)]);
    XCTAssertFalse([matcher evaluateObject:@(123.3)]);
    XCTAssertFalse([matcher evaluateObject:@(123.3) ignoreCase:YES]);
    XCTAssertFalse([matcher evaluateObject:@(123.3) ignoreCase:NO]);
    XCTAssertFalse([matcher evaluateObject:@(YES)]);
}

- (void)testEqualsNumberPayload {
    NSDictionary *json = @{ @"equals": @(123.456) };
    UAJSONValueMatcher *matcher = [UAJSONValueMatcher matcherWhereNumberEquals:@(123.456)];

    // Verify the JSONValue recreates the expected matcher
    NSError *error = nil;
    XCTAssertEqualObjects(matcher, [UAJSONValueMatcher matcherWithJSON:json error:&error]);
    XCTAssertNil(error);
}

- (void)testAtLeast {
    UAJSONValueMatcher *matcher = [UAJSONValueMatcher matcherWhereNumberAtLeast:@(123.35)];
    XCTAssertTrue([matcher evaluateObject:@(123.35)]);
    XCTAssertTrue([matcher evaluateObject:@(123.36)]);
    XCTAssertTrue([matcher evaluateObject:@(123.36) ignoreCase:YES]);
    XCTAssertTrue([matcher evaluateObject:@(123.36) ignoreCase:NO]);

    XCTAssertFalse([matcher evaluateObject:nil]);
    XCTAssertFalse([matcher evaluateObject:matcher]);
    XCTAssertFalse([matcher evaluateObject:@"not cool"]);
    XCTAssertFalse([matcher evaluateObject:@(123)]);
    XCTAssertFalse([matcher evaluateObject:@(123.3)]);
    XCTAssertFalse([matcher evaluateObject:@(123.3) ignoreCase:YES]);
    XCTAssertFalse([matcher evaluateObject:@(123.3) ignoreCase:NO]);
    XCTAssertFalse([matcher evaluateObject:@(YES)]);
}

- (void)testAtLeastPayload {
    NSDictionary *json = @{ @"at_least": @(100) };
    UAJSONValueMatcher *matcher = [UAJSONValueMatcher matcherWhereNumberAtLeast:@(100)];

    // Verify the JSONValue recreates the expected matcher
    NSError *error = nil;
    XCTAssertEqualObjects(matcher, [UAJSONValueMatcher matcherWithJSON:json error:&error]);
    XCTAssertNil(error);
}

- (void)testAtMost {
    UAJSONValueMatcher *matcher = [UAJSONValueMatcher matcherWhereNumberAtMost:@(123.35)];
    XCTAssertTrue([matcher evaluateObject:@(123.35)]);
    XCTAssertTrue([matcher evaluateObject:@(123.34)]);
    XCTAssertTrue([matcher evaluateObject:@(123.34) ignoreCase:YES]);
    XCTAssertTrue([matcher evaluateObject:@(123.34) ignoreCase:NO]);

    XCTAssertFalse([matcher evaluateObject:nil]);
    XCTAssertFalse([matcher evaluateObject:matcher]);
    XCTAssertFalse([matcher evaluateObject:@"not cool"]);
    XCTAssertFalse([matcher evaluateObject:@(123.36)]);
    XCTAssertFalse([matcher evaluateObject:@(123.36) ignoreCase:YES]);
    XCTAssertFalse([matcher evaluateObject:@(123.36) ignoreCase:NO]);
    XCTAssertFalse([matcher evaluateObject:@(124)]);
}

- (void)testAtMostPayload {
    NSDictionary *json = @{ @"at_most": @(100) };
    UAJSONValueMatcher *matcher = [UAJSONValueMatcher matcherWhereNumberAtMost:@(100)];

    // Verify the JSONValue recreates the expected matcher
    NSError *error = nil;
    XCTAssertEqualObjects(matcher, [UAJSONValueMatcher matcherWithJSON:json error:&error]);
    XCTAssertNil(error);
}

- (void)testAtLeastAtMost {
    UAJSONValueMatcher *matcher = [UAJSONValueMatcher matcherWhereNumberAtLeast:@(100) atMost:@(150)];
    XCTAssertTrue([matcher evaluateObject:@(100)]);
    XCTAssertTrue([matcher evaluateObject:@(150)]);
    XCTAssertTrue([matcher evaluateObject:@(123.456)]);
    XCTAssertTrue([matcher evaluateObject:@(123.456) ignoreCase:YES]);
    XCTAssertTrue([matcher evaluateObject:@(123.456) ignoreCase:NO]);

    XCTAssertFalse([matcher evaluateObject:nil]);
    XCTAssertFalse([matcher evaluateObject:matcher]);
    XCTAssertFalse([matcher evaluateObject:@"not cool"]);
    XCTAssertFalse([matcher evaluateObject:@(99)]);
    XCTAssertFalse([matcher evaluateObject:@(151)]);
    XCTAssertFalse([matcher evaluateObject:@(151) ignoreCase:YES]);
    XCTAssertFalse([matcher evaluateObject:@(151) ignoreCase:NO]);
}

- (void)testAtLeastAtMostPayload {
    NSDictionary *json = @{ @"at_least": @(1), @"at_most": @(100) };
    UAJSONValueMatcher *matcher = [UAJSONValueMatcher matcherWhereNumberAtLeast:@(1) atMost:@(100)];

    // Verify the JSONValue recreates the expected matcher
    NSError *error = nil;
    XCTAssertEqualObjects(matcher, [UAJSONValueMatcher matcherWithJSON:json error:&error]);
    XCTAssertNil(error);
}

- (void)testPresence {
    UAJSONValueMatcher *matcher = [UAJSONValueMatcher matcherWhereValueIsPresent:YES];
    XCTAssertTrue([matcher evaluateObject:@(100)]);
    XCTAssertTrue([matcher evaluateObject:matcher]);
    XCTAssertTrue([matcher evaluateObject:@"cool"]);
    XCTAssertTrue([matcher evaluateObject:@"cool" ignoreCase:YES]);
    XCTAssertTrue([matcher evaluateObject:@"cool" ignoreCase:YES]);

    XCTAssertFalse([matcher evaluateObject:nil]);
    XCTAssertFalse([matcher evaluateObject:nil ignoreCase:YES]);
    XCTAssertFalse([matcher evaluateObject:nil ignoreCase:NO]);
}

- (void)testPresencePayload {
    NSDictionary *json = @{ @"is_present": @(YES) };
    UAJSONValueMatcher *matcher = [UAJSONValueMatcher matcherWhereValueIsPresent:YES];

    // Verify the JSONValue recreates the expected matcher
    NSError *error = nil;
    XCTAssertEqualObjects(matcher, [UAJSONValueMatcher matcherWithJSON:json error:&error]);
    XCTAssertNil(error);
}

- (void)testAbsence {
    UAJSONValueMatcher *matcher = [UAJSONValueMatcher matcherWhereValueIsPresent:NO];
    XCTAssertTrue([matcher evaluateObject:nil]);
    XCTAssertTrue([matcher evaluateObject:nil ignoreCase:YES]);
    XCTAssertTrue([matcher evaluateObject:nil ignoreCase:NO]);

    XCTAssertFalse([matcher evaluateObject:@(100)]);
    XCTAssertFalse([matcher evaluateObject:matcher]);
    XCTAssertFalse([matcher evaluateObject:@"cool"]);
    XCTAssertFalse([matcher evaluateObject:@"cool" ignoreCase:YES]);
    XCTAssertFalse([matcher evaluateObject:@"cool" ignoreCase:YES]);
}

- (void)testAbsencePayload {
    NSDictionary *json = @{ @"is_present": @(NO) };
    UAJSONValueMatcher *matcher = [UAJSONValueMatcher matcherWhereValueIsPresent:NO];

    // Verify the JSONValue recreates the expected matcher
    NSError *error = nil;
    XCTAssertEqualObjects(matcher, [UAJSONValueMatcher matcherWithJSON:json error:&error]);
    XCTAssertNil(error);
}

- (void)testVersionRangeConstraints {
    UAJSONValueMatcher *matcher = [UAJSONValueMatcher matcherWithVersionConstraint:@"1.0"];
    XCTAssertNotNil(matcher);
    XCTAssertTrue([matcher evaluateObject:@"1.0"]);
    XCTAssertTrue([matcher evaluateObject:@"1.0" ignoreCase:YES]);
    XCTAssertFalse([matcher evaluateObject:@" 2.0 "]);
    XCTAssertFalse([matcher evaluateObject:@" 2.0 " ignoreCase:YES]);

    matcher = [UAJSONValueMatcher matcherWithVersionConstraint:@"1.0+"];
    XCTAssertNotNil(matcher);
    XCTAssertTrue([matcher evaluateObject:@"1.0"]);
    XCTAssertTrue([matcher evaluateObject:@"1.0.0"]);
    XCTAssertTrue([matcher evaluateObject:@"1.0" ignoreCase:YES]);
    XCTAssertFalse([matcher evaluateObject:@"2"]);
    XCTAssertFalse([matcher evaluateObject:@"2" ignoreCase:YES]);

    matcher = [UAJSONValueMatcher matcherWithVersionConstraint:@"[1.0,2.0]"];
    XCTAssertNotNil(matcher);
    XCTAssertTrue([matcher evaluateObject:@"1.0"]);
    XCTAssertTrue([matcher evaluateObject:@"1.0.0"]);
    XCTAssertTrue([matcher evaluateObject:@"1.0" ignoreCase:YES]);
    XCTAssertTrue([matcher evaluateObject:@"2.0.0"]);
    XCTAssertFalse([matcher evaluateObject:@"2.0.1"]);
    XCTAssertFalse([matcher evaluateObject:@"2.0.1 ignoreCase:YES"]);
}

- (void)testArrayContains {
    UAJSONValueMatcher *valueMatcher = [UAJSONValueMatcher matcherWhereStringEquals:@"bingo"];
    UAJSONMatcher *jsonMatcher = [[UAJSONMatcher alloc] initWithValueMatcher:valueMatcher];
    UAJSONPredicate *predicate = [[UAJSONPredicate alloc] initWithJSONMatcher:jsonMatcher];
    UAJSONValueMatcher *matcher = [UAJSONValueMatcher matcherWithArrayContainsPredicate:predicate];

    XCTAssertNotNil(matcher);

    // Validate matcher payload
    XCTAssertTrue([matcher.payload[@"array_contains"] isKindOfClass:[NSDictionary class]]);

    // Invalid values
    XCTAssertFalse([matcher evaluateObject:@"1.0"]);
    XCTAssertFalse([matcher evaluateObject:@{@"bingo": @"what"}]);
    XCTAssertFalse([matcher evaluateObject:@{@"BINGO": @"what"} ignoreCase:YES]);
    XCTAssertFalse([matcher evaluateObject:@(1)]);
    XCTAssertFalse([matcher evaluateObject:nil]);
    NSArray *value = @[@"thats", @"a", @"BINGO"];
    XCTAssertFalse([matcher evaluateObject:value]);
    XCTAssertFalse([matcher evaluateObject:value ignoreCase:NO]);
    XCTAssertFalse([matcher evaluateObject:value ignoreCase:YES]);
    value = @[@"thats", @"a"];
    XCTAssertFalse([matcher evaluateObject:value]);
    value = @[];
    XCTAssertFalse([matcher evaluateObject:@[]]);

    // Valid values
    value = @[@"thats", @"a", @"bingo"];
    XCTAssertTrue([matcher evaluateObject:value]);
    XCTAssertTrue([matcher evaluateObject:value ignoreCase:NO]);
    XCTAssertTrue([matcher evaluateObject:value ignoreCase:YES]);
    
    // ignore case
    jsonMatcher = [[UAJSONMatcher alloc] initWithValueMatcher:valueMatcher ignoreCase:YES];
    predicate = [[UAJSONPredicate alloc] initWithJSONMatcher:jsonMatcher];
    matcher = [UAJSONValueMatcher matcherWithArrayContainsPredicate:predicate];
    
    value = @[@"thats", @"a", @"BINGO"];
    XCTAssertTrue([matcher evaluateObject:value]);
    XCTAssertTrue([matcher evaluateObject:value ignoreCase:NO]);
    XCTAssertTrue([matcher evaluateObject:value ignoreCase:YES]);
}

- (void)testArrayContainsAtIndex {
    UAJSONValueMatcher *valueMatcher = [UAJSONValueMatcher matcherWhereStringEquals:@"bingo"];
    UAJSONMatcher *jsonMatcher = [[UAJSONMatcher alloc] initWithValueMatcher:valueMatcher];
    UAJSONPredicate *predicate = [[UAJSONPredicate alloc] initWithJSONMatcher:jsonMatcher];
    UAJSONValueMatcher *matcher = [UAJSONValueMatcher matcherWithArrayContainsPredicate:predicate atIndex:1];

    XCTAssertNotNil(matcher);

    // Invalid values
    XCTAssertFalse([matcher evaluateObject:@"1.0"]);
    XCTAssertFalse([matcher evaluateObject:@{@"bingo": @"what"}]);
    XCTAssertFalse([matcher evaluateObject:@{@"bingo": @"what"} ignoreCase:YES]);
    XCTAssertFalse([matcher evaluateObject:@(1)]);
    XCTAssertFalse([matcher evaluateObject:nil]);
    NSArray *value = @[@"thats", @"a", @"BINGO"];
    XCTAssertFalse([matcher evaluateObject:value]);
    XCTAssertFalse([matcher evaluateObject:value ignoreCase:NO]);
    XCTAssertFalse([matcher evaluateObject:value ignoreCase:YES]);
    value = @[@"thats", @"a"];
    XCTAssertFalse([matcher evaluateObject:value]);
    value = @[];
    XCTAssertFalse([matcher evaluateObject:@[]]);
    value = @[@"thats", @"BINGO", @"a"];
    XCTAssertFalse([matcher evaluateObject:value]);
    XCTAssertFalse([matcher evaluateObject:value ignoreCase:NO]);
    XCTAssertFalse([matcher evaluateObject:value ignoreCase:YES]);

    // Valid values
    value = @[@"thats", @"bingo", @"a"];
    XCTAssertTrue([matcher evaluateObject:value]);
    value = @[@"thats", @"bingo"];
    XCTAssertTrue([matcher evaluateObject:value]);
    value = @[@"a", @"bingo"];
    XCTAssertTrue([matcher evaluateObject:value]);

    // ignore case
    jsonMatcher = [[UAJSONMatcher alloc] initWithValueMatcher:valueMatcher ignoreCase:YES];
    predicate = [[UAJSONPredicate alloc] initWithJSONMatcher:jsonMatcher];
    matcher = [UAJSONValueMatcher matcherWithArrayContainsPredicate:predicate atIndex:1];
    
    value = @[@"thats", @"a", @"BINGO"];
    XCTAssertFalse([matcher evaluateObject:value]);
    XCTAssertFalse([matcher evaluateObject:value ignoreCase:NO]);
    XCTAssertFalse([matcher evaluateObject:value ignoreCase:YES]);

    value = @[@"thats", @"BINGO", @"a"];
    XCTAssertTrue([matcher evaluateObject:value]);
    XCTAssertTrue([matcher evaluateObject:value ignoreCase:NO]);
    XCTAssertTrue([matcher evaluateObject:value ignoreCase:YES]);
}

- (void)testVersionMatcher {
    NSError *error;
    UAJSONValueMatcher *matcher = [UAJSONValueMatcher matcherWithJSON:@{ @"version_matches": @"9.9" } error:&error];
    XCTAssertFalse([matcher evaluateObject:@"9.0"]);
    XCTAssertTrue([matcher evaluateObject:@"9.9"]);
    XCTAssertTrue([matcher evaluateObject:@"9.9" ignoreCase:YES]);
    XCTAssertFalse([matcher evaluateObject:@"10.0"]);
    XCTAssertFalse([matcher evaluateObject:@"10.0" ignoreCase:YES]);

    matcher = [UAJSONValueMatcher matcherWithJSON:@{ @"version": @"8.9" } error:&error];
    XCTAssertFalse([matcher evaluateObject:@"8.0"]);
    XCTAssertTrue([matcher evaluateObject:@"8.9"]);
    XCTAssertFalse([matcher evaluateObject:@"9.0"]);
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

    // Invalid range value
    json = @{ @"version_matches": @"cool story" };
    error = nil;
    XCTAssertNil([UAJSONValueMatcher matcherWithJSON:json error:&error]);
    XCTAssertNotNil(error);

    // Invalid range value
    json = @{ @"version": @"cool story" };
    error = nil;
    XCTAssertNil([UAJSONValueMatcher matcherWithJSON:json error:&error]);
    XCTAssertNotNil(error);
    
    // Invalid object
    error = nil;
    XCTAssertNil([UAJSONValueMatcher matcherWithJSON:@"cool" error:&error]);
    XCTAssertNotNil(error);
}

- (void)testValueIsEqualToValueIgnoreCase {
    UAJSONValueMatcher *matcher = [UAJSONValueMatcher matcherWhereStringEquals:@"does_not_matter"];
    
    // valueOne == valueOne
    NSNumber *valueOne = @(1);
    XCTAssertTrue([matcher value:valueOne isEqualToValue:valueOne ignoreCase:nil]);
    XCTAssertTrue([matcher value:valueOne isEqualToValue:valueOne ignoreCase:NO]);
    XCTAssertTrue([matcher value:valueOne isEqualToValue:valueOne ignoreCase:YES]);

    // NSNumber == NSNumber
    XCTAssertTrue([matcher value:valueOne isEqualToValue:@(1) ignoreCase:nil]);
    XCTAssertTrue([matcher value:valueOne isEqualToValue:@(1) ignoreCase:NO]);
    XCTAssertTrue([matcher value:valueOne isEqualToValue:@(1) ignoreCase:YES]);

    XCTAssertTrue([matcher value:@(1) isEqualToValue:@(1) ignoreCase:nil]);
    XCTAssertTrue([matcher value:@(1) isEqualToValue:@(1) ignoreCase:NO]);
    XCTAssertTrue([matcher value:@(1) isEqualToValue:@(1) ignoreCase:YES]);

    // NSString == NSNumber
    XCTAssertFalse([matcher value:@"string" isEqualToValue:@(1) ignoreCase:nil]);
    XCTAssertFalse([matcher value:@"string" isEqualToValue:@(1) ignoreCase:NO]);
    XCTAssertFalse([matcher value:@"string" isEqualToValue:@(1) ignoreCase:YES]);

    // NSString == NSString
    XCTAssertTrue([matcher value:@"string" isEqualToValue:@"string" ignoreCase:nil]);
    XCTAssertTrue([matcher value:@"string" isEqualToValue:@"string" ignoreCase:NO]);
    XCTAssertTrue([matcher value:@"string" isEqualToValue:@"string" ignoreCase:YES]);

    XCTAssertFalse([matcher value:@"string" isEqualToValue:@"strinG" ignoreCase:nil]);
    XCTAssertFalse([matcher value:@"string" isEqualToValue:@"strinG" ignoreCase:NO]);
    XCTAssertTrue([matcher value:@"string" isEqualToValue:@"strinG" ignoreCase:YES]);

    XCTAssertFalse([matcher value:@"string" isEqualToValue:@"strin" ignoreCase:nil]);
    XCTAssertFalse([matcher value:@"string" isEqualToValue:@"strin" ignoreCase:NO]);
    XCTAssertFalse([matcher value:@"string" isEqualToValue:@"strin" ignoreCase:YES]);

    // NSArray == NSString
    XCTAssertFalse([matcher value:@[@"string"] isEqualToValue:@"string" ignoreCase:nil]);
    XCTAssertFalse([matcher value:@[@"string"] isEqualToValue:@"string" ignoreCase:NO]);
    XCTAssertFalse([matcher value:@[@"string"] isEqualToValue:@"string" ignoreCase:YES]);

    // NSArray == NSArray
    NSArray *array1 = @[@"string"];
    NSArray *array1_mixed = @[@"strinG"];
    NSArray *array1b = @[@"strin"];
    XCTAssertTrue([matcher value:array1 isEqualToValue:[array1 copy] ignoreCase:nil]);
    XCTAssertTrue([matcher value:array1 isEqualToValue:[array1 copy] ignoreCase:NO]);
    XCTAssertTrue([matcher value:array1 isEqualToValue:[array1 copy] ignoreCase:YES]);

    XCTAssertFalse([matcher value:array1 isEqualToValue:array1_mixed ignoreCase:nil]);
    XCTAssertFalse([matcher value:array1 isEqualToValue:array1_mixed ignoreCase:NO]);
    XCTAssertTrue([matcher value:array1 isEqualToValue:array1_mixed ignoreCase:YES]);
    
    XCTAssertFalse([matcher value:array1 isEqualToValue:array1b ignoreCase:nil]);
    XCTAssertFalse([matcher value:array1 isEqualToValue:array1b ignoreCase:NO]);
    XCTAssertFalse([matcher value:array1 isEqualToValue:array1b ignoreCase:YES]);
    
    NSArray *array2 = @[@"string",@"string2"];
    NSArray *array2_mixed = @[@"stRing",@"strIng2"];
    NSArray *array2b = @[@"string",@"string"];
    NSArray *array3 = @[@"string",@"string",@"string3"];

    XCTAssertTrue([matcher value:array2 isEqualToValue:[array2 copy] ignoreCase:nil]);
    XCTAssertTrue([matcher value:array2 isEqualToValue:[array2 copy] ignoreCase:NO]);
    XCTAssertTrue([matcher value:array2 isEqualToValue:[array2 copy] ignoreCase:YES]);
    
    XCTAssertFalse([matcher value:array2 isEqualToValue:array2_mixed ignoreCase:nil]);
    XCTAssertFalse([matcher value:array2 isEqualToValue:array2_mixed ignoreCase:NO]);
    XCTAssertTrue([matcher value:array2 isEqualToValue:array2_mixed ignoreCase:YES]);
    
    XCTAssertFalse([matcher value:array2 isEqualToValue:array2b ignoreCase:nil]);
    XCTAssertFalse([matcher value:array2 isEqualToValue:array2b ignoreCase:NO]);
    XCTAssertFalse([matcher value:array2 isEqualToValue:array2b ignoreCase:YES]);

    XCTAssertFalse([matcher value:array2 isEqualToValue:array3 ignoreCase:nil]);
    XCTAssertFalse([matcher value:array2 isEqualToValue:array3 ignoreCase:NO]);
    XCTAssertFalse([matcher value:array2 isEqualToValue:array3 ignoreCase:YES]);

    // NSDictionary == NSArray
    XCTAssertFalse([matcher value:@{@"property":@"string"} isEqualToValue:@[@"string"] ignoreCase:nil]);
    XCTAssertFalse([matcher value:@{@"property":@"string"} isEqualToValue:@[@"string"] ignoreCase:NO]);
    XCTAssertFalse([matcher value:@{@"property":@"string"} isEqualToValue:@[@"string"] ignoreCase:YES]);

    // NSDictionary == NSDictionary
    NSDictionary *dictionary1 = @{@"property":@"string"};
    NSDictionary *dictionary1_mixed = @{@"property":@"strinG"};
    NSDictionary *dictionary1b = @{@"property":@"strin"};
    XCTAssertTrue([matcher value:dictionary1 isEqualToValue:[dictionary1 copy] ignoreCase:nil]);
    XCTAssertTrue([matcher value:dictionary1 isEqualToValue:[dictionary1 copy] ignoreCase:NO]);
    XCTAssertTrue([matcher value:dictionary1 isEqualToValue:[dictionary1 copy] ignoreCase:YES]);
    
    XCTAssertFalse([matcher value:dictionary1 isEqualToValue:dictionary1_mixed ignoreCase:nil]);
    XCTAssertFalse([matcher value:dictionary1 isEqualToValue:dictionary1_mixed ignoreCase:NO]);
    XCTAssertTrue([matcher value:dictionary1 isEqualToValue:dictionary1_mixed ignoreCase:YES]);
    
    XCTAssertFalse([matcher value:dictionary1 isEqualToValue:dictionary1b ignoreCase:nil]);
    XCTAssertFalse([matcher value:dictionary1 isEqualToValue:dictionary1b ignoreCase:NO]);
    XCTAssertFalse([matcher value:dictionary1 isEqualToValue:dictionary1b ignoreCase:YES]);
    
    NSDictionary *dictionary2 = @{@"property1":@"string",@"property2":@"string2"};
    NSDictionary *dictionary2_mixed = @{@"property1":@"stRing",@"property2":@"strIng2"};
    NSDictionary *dictionary2b = @{@"property1":@"string",@"property2":@"string"};
    NSDictionary *dictionary3 = @{@"property1":@"string",@"property2":@"string",@"property3":@"string3"};
    
    XCTAssertTrue([matcher value:dictionary2 isEqualToValue:[dictionary2 copy] ignoreCase:nil]);
    XCTAssertTrue([matcher value:dictionary2 isEqualToValue:[dictionary2 copy] ignoreCase:NO]);
    XCTAssertTrue([matcher value:dictionary2 isEqualToValue:[dictionary2 copy] ignoreCase:YES]);
    
    XCTAssertFalse([matcher value:dictionary2 isEqualToValue:dictionary2_mixed ignoreCase:nil]);
    XCTAssertFalse([matcher value:dictionary2 isEqualToValue:dictionary2_mixed ignoreCase:NO]);
    XCTAssertTrue([matcher value:dictionary2 isEqualToValue:dictionary2_mixed ignoreCase:YES]);
    
    XCTAssertFalse([matcher value:dictionary2 isEqualToValue:dictionary2b ignoreCase:nil]);
    XCTAssertFalse([matcher value:dictionary2 isEqualToValue:dictionary2b ignoreCase:NO]);
    XCTAssertFalse([matcher value:dictionary2 isEqualToValue:dictionary2b ignoreCase:YES]);
    
    XCTAssertFalse([matcher value:dictionary2 isEqualToValue:dictionary3 ignoreCase:nil]);
    XCTAssertFalse([matcher value:dictionary2 isEqualToValue:dictionary3 ignoreCase:NO]);
    XCTAssertFalse([matcher value:dictionary2 isEqualToValue:dictionary3 ignoreCase:YES]);
    
    XCTAssertFalse([matcher value:nil isEqualToValue:@(1) ignoreCase:nil]);
    XCTAssertFalse([matcher value:nil isEqualToValue:@(1) ignoreCase:NO]);
    XCTAssertFalse([matcher value:nil isEqualToValue:@(1) ignoreCase:YES]);
    
    XCTAssertFalse([matcher value:@(1) isEqualToValue:nil ignoreCase:nil]);
    XCTAssertFalse([matcher value:@(1) isEqualToValue:nil ignoreCase:NO]);
    XCTAssertFalse([matcher value:@(1) isEqualToValue:nil ignoreCase:YES]);
}


@end
