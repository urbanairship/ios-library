/* Copyright 2017 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UAJSONMatcher.h"
#import "UAJSONValueMatcher.h"
#import "UAJSONPredicate.h"

@interface UAJSONPredicateTests : UABaseTest
@property (nonatomic, strong) UAJSONMatcher *fooMatcher;
@property (nonatomic, strong) UAJSONMatcher *storyMatcher;
@property (nonatomic, strong) UAJSONMatcher *stringMatcher;


@end

@implementation UAJSONPredicateTests

- (void)setUp {
    [super setUp];

    self.fooMatcher = [UAJSONMatcher matcherWithValueMatcher:[UAJSONValueMatcher matcherWhereStringEquals:@"bar"] key:@"foo"];
    self.storyMatcher = [UAJSONMatcher matcherWithValueMatcher:[UAJSONValueMatcher matcherWhereStringEquals:@"story"] key:@"cool"];
    self.stringMatcher = [UAJSONMatcher matcherWithValueMatcher:[UAJSONValueMatcher matcherWhereStringEquals:@"cool"]];
}

- (void)testJSONMatcherPredicate {
    UAJSONPredicate *predicate = [UAJSONPredicate predicateWithJSONMatcher:self.stringMatcher];
    XCTAssertTrue([predicate evaluateObject:@"cool"]);

    XCTAssertFalse([predicate evaluateObject:nil]);
    XCTAssertFalse([predicate evaluateObject:predicate]);
    XCTAssertFalse([predicate evaluateObject:@"not cool"]);
    XCTAssertFalse([predicate evaluateObject:@(1)]);
    XCTAssertFalse([predicate evaluateObject:@(YES)]);
}

- (void)testJSONMatcherPredicatePayload {
    NSDictionary *json = @{ @"value": @{ @"equals": @"cool" } };
    UAJSONPredicate *predicate = [UAJSONPredicate predicateWithJSONMatcher:self.stringMatcher];

    XCTAssertEqualObjects(json, predicate.payload);

    // Verify the JSONValue recreates the expected payload
    NSError *error = nil;
    XCTAssertEqualObjects(json, [UAJSONPredicate predicateWithJSON:json error:&error].payload);
    XCTAssertNil(error);
}

- (void)testNotPredicate {
    UAJSONPredicate *predicate = [UAJSONPredicate notPredicateWithSubpredicate:[UAJSONPredicate predicateWithJSONMatcher:self.stringMatcher]];
    XCTAssertFalse([predicate evaluateObject:@"cool"]);

    XCTAssertTrue([predicate evaluateObject:nil]);
    XCTAssertTrue([predicate evaluateObject:@"not cool"]);
    XCTAssertTrue([predicate evaluateObject:@(1)]);
    XCTAssertTrue([predicate evaluateObject:@(YES)]);
}

- (void)testNotPredicatePayload {
    NSDictionary *json = @{ @"not": @[ @{ @"value": @{ @"equals": @"cool" }} ] };
    UAJSONPredicate *predicate = [UAJSONPredicate notPredicateWithSubpredicate:[UAJSONPredicate predicateWithJSONMatcher:self.stringMatcher]];

    XCTAssertEqualObjects(json, predicate.payload);

    // Verify the JSONValue recreates the expected payload
    NSError *error = nil;
    XCTAssertEqualObjects(json, [UAJSONPredicate predicateWithJSON:json error:&error].payload);
    XCTAssertNil(error);
}

- (void)testAndPredicate {
    UAJSONPredicate *fooPredicate = [UAJSONPredicate predicateWithJSONMatcher:self.fooMatcher];
    UAJSONPredicate *storyPredicate = [UAJSONPredicate predicateWithJSONMatcher:self.storyMatcher];

    UAJSONPredicate *predicate = [UAJSONPredicate andPredicateWithSubpredicates:@[fooPredicate, storyPredicate]];

    NSDictionary *payload = @{@"foo": @"bar", @"cool": @"story"};
    XCTAssertTrue([predicate evaluateObject:payload]);

    payload = @{@"foo": @"bar", @"cool": @"story", @"something": @"else"};
    XCTAssertTrue([predicate evaluateObject:payload]);

    payload = @{@"foo": @"bar", @"cool": @"book"};
    XCTAssertFalse([predicate evaluateObject:payload]);

    payload = @{@"foo": @"bar"};
    XCTAssertFalse([predicate evaluateObject:payload]);

    payload = @{@"cool": @"story"};
    XCTAssertFalse([predicate evaluateObject:payload]);


    XCTAssertFalse([predicate evaluateObject:nil]);
    XCTAssertFalse([predicate evaluateObject:predicate]);
    XCTAssertFalse([predicate evaluateObject:@"bar"]);
    XCTAssertFalse([predicate evaluateObject:@(1)]);
    XCTAssertFalse([predicate evaluateObject:@(YES)]);
}

- (void)testAndPredicatePayload {
    NSDictionary *json = @{ @"and": @[ @{ @"value": @{ @"equals": @"bar" }, @"key": @"foo" },
                                       @{ @"value": @{ @"equals": @"story" }, @"key": @"cool" } ]};

    UAJSONPredicate *fooPredicate = [UAJSONPredicate predicateWithJSONMatcher:self.fooMatcher];
    UAJSONPredicate *storyPredicate = [UAJSONPredicate predicateWithJSONMatcher:self.storyMatcher];
    UAJSONPredicate *predicate = [UAJSONPredicate andPredicateWithSubpredicates:@[fooPredicate, storyPredicate]];

    XCTAssertEqualObjects(json, predicate.payload);

    // Verify the JSONValue recreates the expected payload
    NSError *error = nil;
    XCTAssertEqualObjects(json, [UAJSONPredicate predicateWithJSON:json error:&error].payload);
    XCTAssertNil(error);
}

- (void)testOrPredicate {
    UAJSONPredicate *fooPredicate = [UAJSONPredicate predicateWithJSONMatcher:self.fooMatcher];
    UAJSONPredicate *storyPredicate = [UAJSONPredicate predicateWithJSONMatcher:self.storyMatcher];

    UAJSONPredicate *predicate = [UAJSONPredicate orPredicateWithSubpredicates:@[fooPredicate, storyPredicate]];

    NSDictionary *payload = @{@"foo": @"bar", @"cool": @"story"};
    XCTAssertTrue([predicate evaluateObject:payload]);

    payload = @{@"foo": @"bar", @"cool": @"story", @"something": @"else"};
    XCTAssertTrue([predicate evaluateObject:payload]);

    payload = @{@"foo": @"bar"};
    XCTAssertTrue([predicate evaluateObject:payload]);

    payload = @{@"cool": @"story"};
    XCTAssertTrue([predicate evaluateObject:payload]);

    payload = @{@"foo": @"not bar", @"cool": @"book"};
    XCTAssertFalse([predicate evaluateObject:payload]);

    XCTAssertFalse([predicate evaluateObject:nil]);
    XCTAssertFalse([predicate evaluateObject:predicate]);
    XCTAssertFalse([predicate evaluateObject:@"bar"]);
    XCTAssertFalse([predicate evaluateObject:@(1)]);
    XCTAssertFalse([predicate evaluateObject:@(YES)]);
}

- (void)testOrPredicatePayload {
    NSDictionary *json = @{ @"or": @[ @{ @"value": @{ @"equals": @"bar" }, @"key": @"foo" },
                                       @{ @"value": @{ @"equals": @"story" }, @"key": @"cool" } ]};

    UAJSONPredicate *fooPredicate = [UAJSONPredicate predicateWithJSONMatcher:self.fooMatcher];
    UAJSONPredicate *storyPredicate = [UAJSONPredicate predicateWithJSONMatcher:self.storyMatcher];
    UAJSONPredicate *predicate = [UAJSONPredicate orPredicateWithSubpredicates:@[fooPredicate, storyPredicate]];

    XCTAssertEqualObjects(json, predicate.payload);

    // Verify the JSONValue recreates the expected payload
    NSError *error = nil;
    XCTAssertEqualObjects(json, [UAJSONPredicate predicateWithJSON:json error:&error].payload);
    XCTAssertNil(error);
}

- (void)testInvalidPayload {
    NSError *error = nil;

    // Invalid type
    NSDictionary *json = @{ @"what": @[ @{ @"value": @{ @"equals": @"bar" }, @"key": @"foo" },
                                      @{ @"value": @{ @"equals": @"story" }, @"key": @"cool" } ]};
    XCTAssertNil([UAJSONMatcher matcherWithJSON:json error:&error]);
    XCTAssertNotNil(error);

    // Invalid key value
    error = nil;
    json = @{ @"or": @[ @"not cool",
                        @{ @"value": @{ @"equals": @"story" }, @"key": @"cool" } ]};
    XCTAssertNil([UAJSONMatcher matcherWithJSON:json error:&error]);
    XCTAssertNotNil(error);

    // Invalid object
    error = nil;
    XCTAssertNil([UAJSONMatcher matcherWithJSON:@"not cool" error:&error]);
    XCTAssertNotNil(error);

}

@end
