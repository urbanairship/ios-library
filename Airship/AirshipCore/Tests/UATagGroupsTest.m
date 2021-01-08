/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UATagGroups.h"

@interface UATagGroupsTest : UABaseTest
@property (nonatomic, strong) UATagGroups *tagGroups;
@end

@implementation UATagGroupsTest

- (void)setUp {
    [super setUp];
    self.tagGroups = [UATagGroups tagGroupsWithTags:@{ @"foo" : [NSSet setWithArray:@[@"baz", @"boz"]], @"bar" : [NSSet setWithArray:@[@"biz"]] }];
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
