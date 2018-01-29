/* Copyright 2018 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UAPreferenceDataStore+InternalTagGroupsMutation.h"

@interface UAPreferenceDataStore_TagGroupsMutationInternalTest : UABaseTest

@property(nonatomic, strong) UAPreferenceDataStore *dataStore;

@end

@implementation UAPreferenceDataStore_TagGroupsMutationInternalTest

- (void)setUp {
    [super setUp];

    self.dataStore = [UAPreferenceDataStore preferenceDataStoreWithKeyPrefix:@"UAPreferenceDataStore_TagGroupsMutationInternalTest"];
}

- (void)tearDown {
    [self.dataStore removeAll];
    [super tearDown];
}

- (void)testAddTagGroupsMutation {
    UATagGroupsMutation *mutation = [UATagGroupsMutation mutationToAddTags:@[@"tag2"] group:@"group"];
    [self.dataStore addTagGroupsMutation:mutation atBeginning:NO forKey:@"test"];

    UATagGroupsMutation *fromStore = [self.dataStore pollTagGroupsMutationForKey:@"test"];
    XCTAssertEqualObjects([mutation payload], [fromStore payload]);
}

- (void)testAddTagGroupsMutationCollapsesMutations {
    UATagGroupsMutation *add = [UATagGroupsMutation mutationToAddTags:@[@"tag1"] group:@"group"];
    UATagGroupsMutation *remove = [UATagGroupsMutation mutationToRemoveTags:@[@"tag2", @"tag1"] group:@"group"];

    [self.dataStore addTagGroupsMutation:remove atBeginning:NO forKey:@"test"];
    [self.dataStore addTagGroupsMutation:add atBeginning:NO forKey:@"test"];

    UATagGroupsMutation *fromStore = [self.dataStore pollTagGroupsMutationForKey:@"test"];

    NSDictionary *expected = @{ @"remove": @{ @"group": @[@"tag2"] }, @"add": @{ @"group": @[@"tag1"] } };
    XCTAssertEqualObjects(expected, [fromStore payload]);
}

- (void)testAddTagGroupsMutationAtBeginning {
    UATagGroupsMutation *add = [UATagGroupsMutation mutationToAddTags:@[@"tag1"] group:@"group"];
    UATagGroupsMutation *set = [UATagGroupsMutation mutationToSetTags:@[@"tag2"] group:@"group"];

    [self.dataStore addTagGroupsMutation:add atBeginning:NO forKey:@"test"];
    [self.dataStore addTagGroupsMutation:set atBeginning:YES forKey:@"test"];

    // Adding the set first shoudl result in set [tag2, tag1]
    UATagGroupsMutation *fromStore = [self.dataStore pollTagGroupsMutationForKey:@"test"];

    NSDictionary *expected = @{ @"set": @{ @"group": @[@"tag2", @"tag1"] } };
    XCTAssertEqualObjects(expected, [fromStore payload]);
}

- (void)testPollTagGroupsMutation {
    XCTAssertNil([self.dataStore pollTagGroupsMutationForKey:@"test"]);

    UATagGroupsMutation *add = [UATagGroupsMutation mutationToAddTags:@[@"tag1"] group:@"group"];
    [self.dataStore addTagGroupsMutation:add atBeginning:NO forKey:@"test"];

    XCTAssertNotNil([self.dataStore pollTagGroupsMutationForKey:@"test"]);
    XCTAssertNil([self.dataStore pollTagGroupsMutationForKey:@"test"]);
}

- (void)testMigrateTagGroupSettings {
    NSDictionary *oldAddTags = @{ @"group1": @[@"tag1"] };
    [self.dataStore setObject:oldAddTags forKey:@"old_add"];

    NSDictionary *oldRemoveTags = @{ @"group2": @[@"tag2"] };
    [self.dataStore setObject:oldRemoveTags forKey:@"old_remove"];

    [self.dataStore migrateTagGroupSettingsForAddTagsKey:@"old_add" removeTagsKey:@"old_remove" newKey:@"test"];

    UATagGroupsMutation *fromStore = [self.dataStore pollTagGroupsMutationForKey:@"test"];
    NSDictionary *expected = @{ @"add": @{ @"group1": @[@"tag1"] }, @"remove": @{ @"group2": @[@"tag2"] } };
    XCTAssertEqualObjects(expected, [fromStore payload]);

}


@end
