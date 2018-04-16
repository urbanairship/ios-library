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
    [self.dataStore addTagGroupsMutation:mutation forKey:@"test"];

    UATagGroupsMutation *fromStore = [self.dataStore popTagGroupsMutationForKey:@"test"];
    XCTAssertEqualObjects([mutation payload], [fromStore payload]);
}

- (void)testAddingMutationsDoesntCollapseMutations {
    UATagGroupsMutation *add = [UATagGroupsMutation mutationToAddTags:@[@"tag1"] group:@"group"];
    UATagGroupsMutation *remove = [UATagGroupsMutation mutationToRemoveTags:@[@"tag2", @"tag1"] group:@"group"];

    [self.dataStore addTagGroupsMutation:remove forKey:@"test"];
    [self.dataStore addTagGroupsMutation:add forKey:@"test"];

    UATagGroupsMutation *fromStore = [self.dataStore popTagGroupsMutationForKey:@"test"];

    NSDictionary *expected = @{ @"remove": @{ @"group": @[@"tag2", @"tag1"] }};
    XCTAssertEqualObjects(expected, [fromStore payload]);

    fromStore = [self.dataStore popTagGroupsMutationForKey:@"test"];
    
    expected = @{ @"add": @{ @"group": @[@"tag1"] }};
    XCTAssertEqualObjects(expected, [fromStore payload]);
}

- (void)testCollapseTagGroupsMutationCollapsesMutations {
    UATagGroupsMutation *add = [UATagGroupsMutation mutationToAddTags:@[@"tag1"] group:@"group"];
    UATagGroupsMutation *remove = [UATagGroupsMutation mutationToRemoveTags:@[@"tag2", @"tag1"] group:@"group"];
    
    [self.dataStore addTagGroupsMutation:remove forKey:@"test"];
    [self.dataStore addTagGroupsMutation:add forKey:@"test"];
    [self.dataStore collapseTagGroupsMutationForKey:@"test"];
    
    UATagGroupsMutation *fromStore = [self.dataStore popTagGroupsMutationForKey:@"test"];
    
    NSDictionary *expected = @{ @"remove": @{ @"group": @[@"tag2"] }, @"add": @{ @"group": @[@"tag1"] } };
    XCTAssertEqualObjects(expected, [fromStore payload]);
}

- (void)testPeekTagGroupsMutation {
    XCTAssertNil([self.dataStore peekTagGroupsMutationForKey:@"test"]);
    
    UATagGroupsMutation *add = [UATagGroupsMutation mutationToAddTags:@[@"tag1"] group:@"group"];
    [self.dataStore addTagGroupsMutation:add forKey:@"test"];
    
    UATagGroupsMutation *peekedMutation = [self.dataStore peekTagGroupsMutationForKey:@"test"];
    XCTAssertNotNil(peekedMutation);
    UATagGroupsMutation *poppedMutation = [self.dataStore popTagGroupsMutationForKey:@"test"];
    XCTAssertNotNil(poppedMutation);
    XCTAssertEqualObjects([peekedMutation payload], [poppedMutation payload]);
    XCTAssertNil([self.dataStore popTagGroupsMutationForKey:@"test"]);
}

- (void)testPopTagGroupsMutation {
    XCTAssertNil([self.dataStore popTagGroupsMutationForKey:@"test"]);

    UATagGroupsMutation *add = [UATagGroupsMutation mutationToAddTags:@[@"tag1"] group:@"group"];
    [self.dataStore addTagGroupsMutation:add forKey:@"test"];

    XCTAssertNotNil([self.dataStore popTagGroupsMutationForKey:@"test"]);
    XCTAssertNil([self.dataStore popTagGroupsMutationForKey:@"test"]);
}

- (void)testMigrateTagGroupSettings {
    NSDictionary *oldAddTags = @{ @"group1": @[@"tag1"] };
    [self.dataStore setObject:oldAddTags forKey:@"old_add"];

    NSDictionary *oldRemoveTags = @{ @"group2": @[@"tag2"] };
    [self.dataStore setObject:oldRemoveTags forKey:@"old_remove"];

    [self.dataStore migrateTagGroupSettingsForAddTagsKey:@"old_add" removeTagsKey:@"old_remove" newKey:@"test"];

    UATagGroupsMutation *fromStore = [self.dataStore popTagGroupsMutationForKey:@"test"];
    NSDictionary *expected = @{ @"add": @{ @"group1": @[@"tag1"] }, @"remove": @{ @"group2": @[@"tag2"] } };
    XCTAssertEqualObjects(expected, [fromStore payload]);

}


@end
