/* Copyright 2018 Urban Airship and Contributors */


#import "UABaseTest.h"
#import <UIKit/UIKit.h>
#import "UATagGroupsMutation+Internal.h"

@interface UATagGroupsMutationTest : UABaseTest

@end

@implementation UATagGroupsMutationTest

- (void)testAddTagsMutation {
    UATagGroupsMutation *mutation = [UATagGroupsMutation mutationToAddTags:@[@"tag2", @"tag2", @"tag1"] group:@"group"];

    NSDictionary *expected = @{ @"add": @{ @"group": @[@"tag2", @"tag1"] } };
    XCTAssertEqualObjects(expected, [mutation payload]);
}

- (void)testSetTagsMutation {
    UATagGroupsMutation *mutation = [UATagGroupsMutation mutationToSetTags:@[@"tag2", @"tag2", @"tag1"] group:@"group"];

    NSDictionary *expected = @{ @"set": @{ @"group": @[@"tag2", @"tag1"] } };
    XCTAssertEqualObjects(expected, [mutation payload]);
}

- (void)testRemoveTagsMutation {
    UATagGroupsMutation *mutation = [UATagGroupsMutation mutationToRemoveTags:@[@"tag2", @"tag2", @"tag1"] group:@"group"];

    NSDictionary *expected = @{ @"remove": @{ @"group": @[@"tag2", @"tag1"] } };
    XCTAssertEqualObjects(expected, [mutation payload]);
}

- (void)testCollapseMutationSameGroup {
    UATagGroupsMutation *add = [UATagGroupsMutation mutationToAddTags:@[@"tag1", @"tag2"] group:@"group"];
    UATagGroupsMutation *remove = [UATagGroupsMutation mutationToRemoveTags:@[@"tag1"] group:@"group"];
    UATagGroupsMutation *set = [UATagGroupsMutation mutationToSetTags:@[@"tag3"] group:@"group"];

    // Collapse [add, remove] should result in a single mutation to add [tag2] remove [tag1]
    NSArray *collapsed = [UATagGroupsMutation collapseMutations:@[add, remove]];
    XCTAssertEqual(1, collapsed.count);

    NSDictionary *expected = @{ @"add": @{ @"group": @[@"tag2"] }, @"remove": @{ @"group": @[@"tag1"] } };
    XCTAssertEqualObjects(expected, [collapsed[0] payload]);

    // Collapse [remove, add] order and it should result in add [tag1, tag2]
    collapsed = [UATagGroupsMutation collapseMutations:@[remove, add]];
    XCTAssertEqual(1, collapsed.count);

    expected = @{ @"add": @{ @"group": @[@"tag2", @"tag1"] } };
    XCTAssertEqualObjects(expected, [collapsed[0] payload]);

    // Collapse [set, add, remove] should result in a single mutation to set [tag2, tag3]
    collapsed = [UATagGroupsMutation collapseMutations:@[set, add, remove]];
    XCTAssertEqual(1, collapsed.count);

    expected = @{ @"set": @{ @"group": @[@"tag2", @"tag3"] } };
    XCTAssertEqualObjects(expected, [collapsed[0] payload]);

    // Collapse [add, set, remove] should result in single mutation to set [tag3]
    collapsed = [UATagGroupsMutation collapseMutations:@[add, set, remove]];
    XCTAssertEqual(1, collapsed.count);

    expected = @{ @"set": @{ @"group": @[@"tag3"] } };
    XCTAssertEqualObjects(expected, [collapsed[0] payload]);

    // Collapse [set, remove, add] should result in single mutation to set [tag3, tag1, tag2]
    collapsed = [UATagGroupsMutation collapseMutations:@[set, remove, add]];
    XCTAssertEqual(1, collapsed.count);

    expected = @{ @"set": @{ @"group": @[@"tag2", @"tag1", @"tag3"] } };
    XCTAssertEqualObjects(expected, [collapsed[0] payload]);

    // Collapse multiple adds should result in a single add [tag1, tag2]
    collapsed = [UATagGroupsMutation collapseMutations:@[add, add, add, add]];

    expected = @{ @"add": @{ @"group": @[@"tag2", @"tag1"] } };
    XCTAssertEqualObjects(expected, [collapsed[0] payload]);
}

- (void)testCollapseMultipleGroups {
    UATagGroupsMutation *addGroup1 = [UATagGroupsMutation mutationToAddTags:@[@"tag1", @"tag2"] group:@"group1"];
    UATagGroupsMutation *removeGroup2 = [UATagGroupsMutation mutationToRemoveTags:@[@"tag1"] group:@"group2"];
    UATagGroupsMutation *setGroup3 = [UATagGroupsMutation mutationToSetTags:@[@"tag3"] group:@"group3"];
    UATagGroupsMutation *setGroup1 = [UATagGroupsMutation mutationToSetTags:@[@"tag4"] group:@"group1"];

    // Collapse [addGroup1, removeGroup2, setGroup3] should result in 2 mutations
    NSArray *collapsed = [UATagGroupsMutation collapseMutations:@[addGroup1, removeGroup2, setGroup3]];
    XCTAssertEqual(2, collapsed.count);

    NSDictionary *expected = @{ @"set": @{ @"group3": @[@"tag3"] } };
    XCTAssertEqualObjects(expected, [collapsed[0] payload]);

    expected = @{ @"add": @{ @"group1": @[@"tag2", @"tag1"] }, @"remove": @{ @"group2": @[@"tag1"] } };
    XCTAssertEqualObjects(expected, [collapsed[1] payload]);

    // Collapse result with setGroup1 should result in 2 mutations
    NSMutableArray *array = [collapsed mutableCopy];
    [array addObject:setGroup1];

    collapsed = [UATagGroupsMutation collapseMutations:array];
    XCTAssertEqual(2, collapsed.count);

    expected = @{ @"set": @{ @"group3": @[@"tag3"], @"group1": @[@"tag4"] } };
    XCTAssertEqualObjects(expected, [collapsed[0] payload]);

    expected = @{ @"remove": @{ @"group2": @[@"tag1"] } };
    XCTAssertEqualObjects(expected, [collapsed[1] payload]);
}

- (void)testCollapseEmptyMutations {
    NSArray *collapsed = [UATagGroupsMutation collapseMutations:@[]];
    XCTAssertEqual(0, collapsed.count);
}

- (void)testCollapseResultsNoMutations {
    UATagGroupsMutation *set = [UATagGroupsMutation mutationToSetTags:@[@"tag1"] group:@"group"];
    UATagGroupsMutation *remove = [UATagGroupsMutation mutationToRemoveTags:@[@"tag1"] group:@"group"];

    // Collapse [set, remove] should result in no mutations
    NSArray *collapsed = [UATagGroupsMutation collapseMutations:@[set, remove]];
    XCTAssertEqual(1, collapsed.count);

    NSDictionary *expected = @{ @"set": @{ @"group": @[] } };
    XCTAssertEqualObjects(expected, [collapsed[0] payload]);
}

- (void)testCollapseSetTags {
    UATagGroupsMutation *set1 = [UATagGroupsMutation mutationToSetTags:@[@"tag1"] group:@"group"];
    UATagGroupsMutation *set2 = [UATagGroupsMutation mutationToSetTags:@[@"tag2"] group:@"group"];

    // Collapse [set1, set2] should result in only set2
    NSArray *collapsed = [UATagGroupsMutation collapseMutations:@[set1, set2]];
    XCTAssertEqual(1, collapsed.count);

    NSDictionary *expected = @{ @"set": @{ @"group": @[@"tag2"] } };
    XCTAssertEqualObjects(expected, [collapsed[0] payload]);
}

@end
