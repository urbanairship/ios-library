/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAPendingTagGroupStore+Internal.h"
#import "UATagGroupsRegistrar+Internal.h"

@interface UAPendingTagGroupStoreTest : UAAirshipBaseTest

@property(nonatomic, strong) UAPendingTagGroupStore *pendingTagGroupStore;

@end

@implementation UAPendingTagGroupStoreTest

- (void)setUp {
    [super setUp];
    self.pendingTagGroupStore = [UAPendingTagGroupStore channelHistoryWithDataStore:self.dataStore];
    
}

- (void)tearDown {
    [self.pendingTagGroupStore clearPendingMutations];
    [super tearDown];
}

- (void)testAddPendingMutation {
    UATagGroupsMutation *mutation = [UATagGroupsMutation mutationToAddTags:@[@"tag2"] group:@"group"];
    [self.pendingTagGroupStore addPendingMutation:mutation];

    UATagGroupsMutation *fromHistory = [self.pendingTagGroupStore popPendingMutation];
    XCTAssertEqualObjects(mutation.payload, fromHistory.payload);
}

- (void)testAddingPendingMutationsDoesntCollapseMutations {
    UATagGroupsMutation *add = [UATagGroupsMutation mutationToAddTags:@[@"tag1"] group:@"group"];
    UATagGroupsMutation *remove = [UATagGroupsMutation mutationToRemoveTags:@[@"tag2", @"tag1"] group:@"group"];

    [self.pendingTagGroupStore addPendingMutation:remove];
    [self.pendingTagGroupStore addPendingMutation:add];

    UATagGroupsMutation *fromHistory = [self.pendingTagGroupStore popPendingMutation];

    NSDictionary *expected = @{ @"remove": @{ @"group": @[@"tag2", @"tag1"] }};
    XCTAssertEqualObjects(expected, fromHistory.payload);

    fromHistory = [self.pendingTagGroupStore popPendingMutation];
    
    expected = @{ @"add": @{ @"group": @[@"tag1"] }};
    XCTAssertEqualObjects(expected, fromHistory.payload);
}

- (void)testCollapsePendingMutations {
    UATagGroupsMutation *add = [UATagGroupsMutation mutationToAddTags:@[@"tag1"] group:@"group"];
    UATagGroupsMutation *remove = [UATagGroupsMutation mutationToRemoveTags:@[@"tag2", @"tag1"] group:@"group"];

    [self.pendingTagGroupStore addPendingMutation:remove];
    [self.pendingTagGroupStore addPendingMutation:add];
    [self.pendingTagGroupStore collapsePendingMutations];
    
    UATagGroupsMutation *fromHistory = [self.pendingTagGroupStore popPendingMutation];
    
    NSDictionary *expected = @{ @"remove": @{ @"group": @[@"tag2"] }, @"add": @{ @"group": @[@"tag1"] } };
    XCTAssertEqualObjects(expected, fromHistory.payload);
}

- (void)testPeekPendingMutation {
    XCTAssertNil([self.pendingTagGroupStore peekPendingMutation]);
    
    UATagGroupsMutation *add = [UATagGroupsMutation mutationToAddTags:@[@"tag1"] group:@"group"];
    [self.pendingTagGroupStore addPendingMutation:add];
    
    UATagGroupsMutation *peekedMutation = [self.pendingTagGroupStore peekPendingMutation];
    XCTAssertNotNil(peekedMutation);
    UATagGroupsMutation *poppedMutation = [self.pendingTagGroupStore popPendingMutation];
    XCTAssertNotNil(poppedMutation);
    XCTAssertEqualObjects(peekedMutation.payload, poppedMutation.payload);
    XCTAssertNil([self.pendingTagGroupStore popPendingMutation]);
}

- (void)testPopPendingMutation {
    XCTAssertNil([self.pendingTagGroupStore popPendingMutation]);

    UATagGroupsMutation *add = [UATagGroupsMutation mutationToAddTags:@[@"tag1"] group:@"group"];
    [self.pendingTagGroupStore addPendingMutation:add];

    XCTAssertNotNil([self.pendingTagGroupStore popPendingMutation]);
    XCTAssertNil([self.pendingTagGroupStore popPendingMutation]);
}

- (void)testMigration {
    NSDictionary *oldAddTags = @{ @"group1": @[@"tag1"] };
    [self.dataStore setObject:oldAddTags forKey:@"UAPushAddTagGroups"];

    NSDictionary *oldRemoveTags = @{ @"group2": @[@"tag2"] };
    [self.dataStore setObject:oldRemoveTags forKey:@"UAPushRemoveTagGroups"];

    UATagGroupsMutation *oldMutation = [UATagGroupsMutation mutationToAddTags:@[@"foo", @"bar"] group:@"group1"];
    NSData *encodedMutations = [NSKeyedArchiver archivedDataWithRootObject:@[oldMutation]];
    [self.dataStore setObject:encodedMutations forKey:@"UAPushTagGroupsMutations"];

    UAPendingTagGroupStore *channelTagGroupsMutationHistory = [UAPendingTagGroupStore channelHistoryWithDataStore:self.dataStore];

    UATagGroupsMutation *oldAddRemoveFromHistory = [channelTagGroupsMutationHistory popPendingMutation];
    NSDictionary *expected = @{ @"add": @{ @"group1": @[@"tag1"] }, @"remove": @{ @"group2": @[@"tag2"] } };
    XCTAssertEqualObjects(expected, oldAddRemoveFromHistory.payload);

    UATagGroupsMutation *oldMutationFromHistory = [channelTagGroupsMutationHistory popPendingMutation];
    XCTAssertEqualObjects(oldMutation.payload, oldMutationFromHistory.payload);
}

@end
