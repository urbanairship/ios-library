/* Copyright 2018 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UATagGroups+Internal.h"
#import "UAirship.h"
#import "UAPush.h"

@interface UATagGroupsTest : UABaseTest
@property(nonatomic, strong) id mockAirship;
@property(nonatomic, strong) id mockPush;
@property (nonatomic, strong) UATagGroups *tagGroups;
@end

@implementation UATagGroupsTest

- (void)setUp {
    [super setUp];
    self.mockAirship = [self mockForClass:[UAirship class]];
    self.mockPush = [self mockForClass:[UAPush class]];

    [[[self.mockAirship stub] andReturn:self.mockPush] push];
    [[[self.mockPush stub] andReturn:@[@"test"]] tags];

    self.tagGroups = [UATagGroups tagGroupsWithTags:@{ @"foo" : [NSSet setWithArray:@[@"baz", @"boz"]], @"bar" : [NSSet setWithArray:@[@"biz"]] }];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testCoding {
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.tagGroups];
    UATagGroups *decoded = [NSKeyedUnarchiver unarchiveObjectWithData:data];

    XCTAssertEqualObjects(decoded, self.tagGroups);
}

- (void)testNormalization {
    UATagGroups *tagGroups = [UATagGroups tagGroupsWithTags:@{@"foo" : @[@"baz", @"boz"], @"bar" : @[@"biz"]}];
    XCTAssertEqualObjects(tagGroups, self.tagGroups);
}

- (void)testContainsOnlyDeviceTags {
    XCTAssertFalse([self.tagGroups containsOnlyDeviceTags]);

    UATagGroups *onlyDeviceTags = [UATagGroups tagGroupsWithTags:@{@"device" : @[@"cool"]}];
    XCTAssertTrue([onlyDeviceTags containsOnlyDeviceTags]);
}

- (void)testContainsAllTags {
    UATagGroups *tagGroups = [UATagGroups tagGroupsWithTags:@{@"foo" : @[@"baz", @"boz"]}];
    XCTAssertTrue([self.tagGroups containsAllTags:tagGroups]);

    tagGroups = [UATagGroups tagGroupsWithTags:@{@"foo" : @[@"bazzzz", @"boz"]}];
    XCTAssertFalse([self.tagGroups containsAllTags:tagGroups]);

    tagGroups = [UATagGroups tagGroupsWithTags:@{@"foo" : @[@"baz", @"boz"], @"blah" : @[@"bloo"]}];
    XCTAssertFalse([self.tagGroups containsAllTags:tagGroups]);
}

- (void)testIntersect {
    UATagGroups *tagGroups = [UATagGroups tagGroupsWithTags:@{@"bar" : @[@"biz", @"bez"]}];
    UATagGroups *expected = [UATagGroups tagGroupsWithTags:@{@"bar" : @[@"biz"]}];

    XCTAssertEqualObjects([tagGroups intersect:self.tagGroups], expected);
}

- (void)testMerge {
    UATagGroups *tags = [UATagGroups tagGroupsWithTags:@{@"bar" : @[@"biz", @"bez"]}];
    UATagGroups *moreTags = [UATagGroups tagGroupsWithTags:@{@"bar" : @[@"bloop"]}];

    UATagGroups *expected = [UATagGroups tagGroupsWithTags:@{@"bar" : @[@"biz", @"bez", @"bloop"]}];

    XCTAssertEqualObjects(expected, [tags merge:moreTags]);
    XCTAssertEqualObjects(expected, [moreTags merge:tags]);
}

@end
