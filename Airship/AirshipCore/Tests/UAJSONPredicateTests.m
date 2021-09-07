/* Copyright Airship and Contributors */

#import "UABaseTest.h"

@import AirshipCore;

@interface UAJSONPredicateTests : UABaseTest
@property (nonatomic, strong) UAJSONMatcher *fooMatcher;
@property (nonatomic, strong) UAJSONMatcher *storyMatcher;
@property (nonatomic, strong) UAJSONMatcher *stringMatcher;


@end

@implementation UAJSONPredicateTests

- (void)setUp {
    [super setUp];

    self.fooMatcher = [[UAJSONMatcher alloc] initWithValueMatcher:[UAJSONValueMatcher matcherWhereStringEquals:@"bar"] scope:@[@"foo"]];
    self.storyMatcher = [[UAJSONMatcher alloc] initWithValueMatcher:[UAJSONValueMatcher matcherWhereStringEquals:@"story"] scope:@[@"cool"]];
    self.stringMatcher = [[UAJSONMatcher alloc] initWithValueMatcher:[UAJSONValueMatcher matcherWhereStringEquals:@"cool"]];
}

- (void)testJSONMatcherPredicate {
    UAJSONPredicate *predicate = [[UAJSONPredicate alloc] initWithJSONMatcher:self.stringMatcher];
    XCTAssertTrue([predicate evaluateObject:@"cool"]);

    XCTAssertFalse([predicate evaluateObject:nil]);
    XCTAssertFalse([predicate evaluateObject:predicate]);
    XCTAssertFalse([predicate evaluateObject:@"not cool"]);
    XCTAssertFalse([predicate evaluateObject:@(1)]);
    XCTAssertFalse([predicate evaluateObject:@(YES)]);
}

- (void)testJSONMatcherPredicatePayload {
    NSDictionary *json = @{ @"value": @{ @"equals": @"cool" } };
    UAJSONPredicate *predicate = [[UAJSONPredicate alloc] initWithJSONMatcher:self.stringMatcher];

    XCTAssertEqualObjects(json, predicate.payload);

    // Verify the JSONValue recreates the expected payload
    NSError *error = nil;
    XCTAssertEqualObjects(json, [[UAJSONPredicate alloc] initWithJSON:json error:&error].payload);
    XCTAssertNil(error);
}

- (void)testNotPredicate {
    UAJSONPredicate *predicate = [UAJSONPredicate notPredicateWithSubpredicate:[[UAJSONPredicate alloc] initWithJSONMatcher:self.stringMatcher]];
    XCTAssertFalse([predicate evaluateObject:@"cool"]);

    XCTAssertTrue([predicate evaluateObject:nil]);
    XCTAssertTrue([predicate evaluateObject:@"not cool"]);
    XCTAssertTrue([predicate evaluateObject:@(1)]);
    XCTAssertTrue([predicate evaluateObject:@(YES)]);
}

- (void)testNotPredicatePayload {
    NSDictionary *json = @{ @"not": @[ @{ @"value": @{ @"equals": @"cool" }} ] };
    UAJSONPredicate *predicate = [UAJSONPredicate notPredicateWithSubpredicate:[[UAJSONPredicate alloc] initWithJSONMatcher:self.stringMatcher]];

    XCTAssertEqualObjects(json, predicate.payload);

    // Verify the JSONValue recreates the expected payload
    NSError *error = nil;
    XCTAssertEqualObjects(json, [[UAJSONPredicate alloc] initWithJSON:json error:&error].payload);
    XCTAssertNil(error);
}

- (void)testAndPredicate {
    UAJSONPredicate *fooPredicate = [[UAJSONPredicate alloc] initWithJSONMatcher:self.fooMatcher];
    UAJSONPredicate *storyPredicate = [[UAJSONPredicate alloc] initWithJSONMatcher:self.storyMatcher];

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
    NSDictionary *json = @{ @"and": @[ @{ @"value": @{ @"equals": @"bar" }, @"scope": @[@"foo"] },
                                       @{ @"value": @{ @"equals": @"story" }, @"scope": @[@"cool"] } ]};

    UAJSONPredicate *fooPredicate = [[UAJSONPredicate alloc] initWithJSONMatcher:self.fooMatcher];
    UAJSONPredicate *storyPredicate = [[UAJSONPredicate alloc] initWithJSONMatcher:self.storyMatcher];
    UAJSONPredicate *predicate = [UAJSONPredicate andPredicateWithSubpredicates:@[fooPredicate, storyPredicate]];

    XCTAssertEqualObjects(json, predicate.payload);

    // Verify the JSONValue recreates the expected payload
    NSError *error = nil;
    XCTAssertEqualObjects(json, [[UAJSONPredicate alloc] initWithJSON:json error:&error].payload);
    XCTAssertNil(error);
}

- (void)testOrPredicate {
    UAJSONPredicate *fooPredicate = [[UAJSONPredicate alloc] initWithJSONMatcher:self.fooMatcher];
    UAJSONPredicate *storyPredicate = [[UAJSONPredicate alloc] initWithJSONMatcher:self.storyMatcher];

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
    NSDictionary *json = @{ @"or": @[ @{ @"value": @{ @"equals": @"bar" }, @"scope": @[@"foo"] },
                                       @{ @"value": @{ @"equals": @"story" }, @"scope": @[@"cool"] } ]};

    UAJSONPredicate *fooPredicate = [[UAJSONPredicate alloc] initWithJSONMatcher:self.fooMatcher];
    UAJSONPredicate *storyPredicate = [[UAJSONPredicate alloc] initWithJSONMatcher:self.storyMatcher];
    UAJSONPredicate *predicate = [UAJSONPredicate orPredicateWithSubpredicates:@[fooPredicate, storyPredicate]];

    XCTAssertEqualObjects(json, predicate.payload);

    // Verify the JSONValue recreates the expected payload
    NSError *error = nil;
    XCTAssertEqualObjects(json, [[UAJSONPredicate alloc] initWithJSON:json error:&error].payload);
    XCTAssertNil(error);
}

- (void)testEqualArray {
    NSDictionary *json = @{ @"value": @{ @"equals": @[@"cool", @"story"]} };

    NSError *error = nil;
    UAJSONPredicate *predicate = [[UAJSONPredicate alloc] initWithJSON:json error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(predicate);

    id value;
    value = @[@"cool", @"story"];
    XCTAssertTrue([predicate evaluateObject:value]);

    value = @[@"cool"];
    XCTAssertFalse([predicate evaluateObject:value]);

    value = @[@"cool", @"story", @"another key"];
    XCTAssertFalse([predicate evaluateObject:value]);

    XCTAssertFalse([predicate evaluateObject:nil]);
    XCTAssertFalse([predicate evaluateObject:predicate]);
    XCTAssertFalse([predicate evaluateObject:@"bar"]);
    XCTAssertFalse([predicate evaluateObject:@(1)]);
    XCTAssertFalse([predicate evaluateObject:@(YES)]);
}

- (void)testEqualObject {
    NSDictionary *json = @{ @"value": @{ @"equals": @{ @"cool": @"story" } } };

    NSError *error = nil;
    UAJSONPredicate *predicate = [[UAJSONPredicate alloc] initWithJSON:json error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(predicate);

    id value;
    value = @{ @"cool": @"story"};
    XCTAssertTrue([predicate evaluateObject:value]);

    value = @{ @"cool": @"story?"};
    XCTAssertFalse([predicate evaluateObject:value]);

    value = @{ @"cool": @"story", @"another_key": @"another_value" };
    XCTAssertFalse([predicate evaluateObject:value]);

    XCTAssertFalse([predicate evaluateObject:nil]);
    XCTAssertFalse([predicate evaluateObject:predicate]);
    XCTAssertFalse([predicate evaluateObject:@"bar"]);
    XCTAssertFalse([predicate evaluateObject:@(1)]);
    XCTAssertFalse([predicate evaluateObject:@(YES)]);
}


- (void)testInvalidPayload {
    NSError *error = nil;

    // Invalid type
    NSDictionary *json = @{ @"what": @[ @{ @"value": @{ @"equals": @"bar" }, @"key": @"foo" },
                                      @{ @"value": @{ @"equals": @"story" }, @"key": @"cool" } ]};
    XCTAssertNil([[UAJSONPredicate alloc] initWithJSON:json error:&error]);
    XCTAssertNotNil(error);

    // Invalid key value
    error = nil;
    json = @{ @"or": @[ @"not cool",
                        @{ @"value": @{ @"equals": @"story" }, @"key": @"cool" } ]};
    XCTAssertNil([[UAJSONPredicate alloc] initWithJSON:json error:&error]);
    XCTAssertNotNil(error);

    // Invalid object
    error = nil;
    XCTAssertNil([[UAJSONPredicate alloc] initWithJSON:@"not cool" error:&error]);
    XCTAssertNotNil(error);

}

@end
