/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UATagGroupsMutationHistory+Internal.h"

@interface UATagGroupsMutationHistoryTest : UAAirshipBaseTest

@property(nonatomic, strong) UATagGroupsMutationHistory *mutationHistory;

@end

@implementation UATagGroupsMutationHistoryTest

- (void)setUp {
    [super setUp];
    self.mutationHistory = [UATagGroupsMutationHistory historyWithDataStore:self.dataStore];
}

- (void)tearDown {
    [self.mutationHistory clearAll];
    [super tearDown];
}

- (void)testAddPendingMutation {
    UATagGroupsMutation *mutation = [UATagGroupsMutation mutationToAddTags:@[@"tag2"] group:@"group"];
    [self.mutationHistory addPendingMutation:mutation type:UATagGroupsTypeChannel];

    UATagGroupsMutation *fromHistory = [self.mutationHistory popPendingMutation:UATagGroupsTypeChannel];
    XCTAssertEqualObjects(mutation.payload, fromHistory.payload);
}

- (void)testAddingPendingMutationsDoesntCollapseMutations {
    UATagGroupsMutation *add = [UATagGroupsMutation mutationToAddTags:@[@"tag1"] group:@"group"];
    UATagGroupsMutation *remove = [UATagGroupsMutation mutationToRemoveTags:@[@"tag2", @"tag1"] group:@"group"];

    [self.mutationHistory addPendingMutation:remove type:UATagGroupsTypeChannel];
    [self.mutationHistory addPendingMutation:add type:UATagGroupsTypeChannel];

    UATagGroupsMutation *fromHistory = [self.mutationHistory popPendingMutation:UATagGroupsTypeChannel];

    NSDictionary *expected = @{ @"remove": @{ @"group": @[@"tag2", @"tag1"] }};
    XCTAssertEqualObjects(expected, fromHistory.payload);

    fromHistory = [self.mutationHistory popPendingMutation:UATagGroupsTypeChannel];
    
    expected = @{ @"add": @{ @"group": @[@"tag1"] }};
    XCTAssertEqualObjects(expected, fromHistory.payload);
}

- (void)testCollapsePendingMutations {
    UATagGroupsMutation *add = [UATagGroupsMutation mutationToAddTags:@[@"tag1"] group:@"group"];
    UATagGroupsMutation *remove = [UATagGroupsMutation mutationToRemoveTags:@[@"tag2", @"tag1"] group:@"group"];

    [self.mutationHistory addPendingMutation:remove type:UATagGroupsTypeChannel];
    [self.mutationHistory addPendingMutation:add type:UATagGroupsTypeChannel];
    [self.mutationHistory collapsePendingMutations:UATagGroupsTypeChannel];
    
    UATagGroupsMutation *fromHistory = [self.mutationHistory popPendingMutation:UATagGroupsTypeChannel];
    
    NSDictionary *expected = @{ @"remove": @{ @"group": @[@"tag2"] }, @"add": @{ @"group": @[@"tag1"] } };
    XCTAssertEqualObjects(expected, fromHistory.payload);
}

- (void)testPeekPendingMutation {
    XCTAssertNil([self.mutationHistory peekPendingMutation:UATagGroupsTypeChannel]);
    
    UATagGroupsMutation *add = [UATagGroupsMutation mutationToAddTags:@[@"tag1"] group:@"group"];
    [self.mutationHistory addPendingMutation:add type:UATagGroupsTypeChannel];
    
    UATagGroupsMutation *peekedMutation = [self.mutationHistory peekPendingMutation:UATagGroupsTypeChannel];
    XCTAssertNotNil(peekedMutation);
    UATagGroupsMutation *poppedMutation = [self.mutationHistory popPendingMutation:UATagGroupsTypeChannel];
    XCTAssertNotNil(poppedMutation);
    XCTAssertEqualObjects(peekedMutation.payload, poppedMutation.payload);
    XCTAssertNil([self.mutationHistory popPendingMutation:UATagGroupsTypeChannel]);
}

- (void)testPopPendingMutation {
    XCTAssertNil([self.mutationHistory popPendingMutation:UATagGroupsTypeChannel]);

    UATagGroupsMutation *add = [UATagGroupsMutation mutationToAddTags:@[@"tag1"] group:@"group"];
    [self.mutationHistory addPendingMutation:add type:UATagGroupsTypeChannel];

    XCTAssertNotNil([self.mutationHistory popPendingMutation:UATagGroupsTypeChannel]);
    XCTAssertNil([self.mutationHistory popPendingMutation:UATagGroupsTypeChannel]);
}

- (void)testMigration {
    NSDictionary *oldAddTags = @{ @"group1": @[@"tag1"] };
    [self.dataStore setObject:oldAddTags forKey:@"UAPushAddTagGroups"];

    NSDictionary *oldRemoveTags = @{ @"group2": @[@"tag2"] };
    [self.dataStore setObject:oldRemoveTags forKey:@"UAPushRemoveTagGroups"];

    UATagGroupsMutation *oldMutation = [UATagGroupsMutation mutationToAddTags:@[@"foo", @"bar"] group:@"group1"];
    NSData *encodedMutations = [NSKeyedArchiver archivedDataWithRootObject:@[oldMutation]];
    [self.dataStore setObject:encodedMutations forKey:@"UAPushTagGroupsMutations"];

    UATagGroupsMutationHistory *history = [UATagGroupsMutationHistory historyWithDataStore:self.dataStore];

    UATagGroupsMutation *oldAddRemoveFromHistory = [history popPendingMutation:UATagGroupsTypeChannel];
    NSDictionary *expected = @{ @"add": @{ @"group1": @[@"tag1"] }, @"remove": @{ @"group2": @[@"tag2"] } };
    XCTAssertEqualObjects(expected, oldAddRemoveFromHistory.payload);

    UATagGroupsMutation *oldMutationFromHistory = [history popPendingMutation:UATagGroupsTypeChannel];
    XCTAssertEqualObjects(oldMutation.payload, oldMutationFromHistory.payload);
}

- (void)testApplyMutations {
    UATagGroups *tagGroups = [UATagGroups tagGroupsWithTags:@{ @"group1": @[@"tag1", @"tag2"], @"group2" : @[@"tag3", @"tag4"] }];

    UATagGroupsMutation *mutation1 = [UATagGroupsMutation mutationToAddTags:@[@"foo", @"bar"] group:@"group1"];
    UATagGroupsMutation *mutation2 = [UATagGroupsMutation mutationToRemoveTags:@[@"tag3"] group:@"group2"];

    [self.mutationHistory addPendingMutation:mutation1 type:UATagGroupsTypeChannel];
    [self.mutationHistory addPendingMutation:mutation2 type:UATagGroupsTypeChannel];

    NSTimeInterval maxAge = 60 * 60;

    UATagGroupsMutation *mutation3 = [UATagGroupsMutation mutationToSetTags:@[@"baz", @"boz"] group:@"group3"];
    UATagGroupsMutation *mutation4 = [UATagGroupsMutation mutationToSetTags:@[@"bleep", @"bloop"] group:@"group4"];

    NSDate *recent = [NSDate dateWithTimeIntervalSinceNow:-(maxAge/2)];
    NSDate *old = [NSDate distantPast];

    [self.mutationHistory addSentMutation:mutation3 date:recent];
    [self.mutationHistory addSentMutation:mutation4 date:old];

    UATagGroups *newTagGroups = [self.mutationHistory applyHistory:tagGroups maxAge:maxAge];

    UATagGroups *expectedTagGroups = [UATagGroups tagGroupsWithTags:@{ @"group1" : @[@"tag1", @"tag2", @"foo", @"bar"],
                                                                       @"group2" : @[@"tag4"],
                                                                       @"group3" : @[@"baz", @"boz"] }];

    XCTAssertEqualObjects(newTagGroups, expectedTagGroups);
}

- (void)testSentMutationsCleansOldRecords {
    UATagGroupsMutation *mutation1 = [UATagGroupsMutation mutationToSetTags:@[@"baz", @"boz"] group:@"group3"];
    UATagGroupsMutation *mutation2 = [UATagGroupsMutation mutationToSetTags:@[@"bleep", @"bloop"] group:@"group4"];

    NSTimeInterval maxAge = 60 * 60;

    NSDate *recent = [NSDate dateWithTimeIntervalSinceNow:-(maxAge/2)];
    NSDate *old = [NSDate distantPast];

    [self.mutationHistory addSentMutation:mutation1 date:recent];
    [self.mutationHistory addSentMutation:mutation2 date:old];

    NSArray<UATagGroupsMutation *> *sent = [self.mutationHistory sentMutationsWithMaxAge:maxAge];

    XCTAssertEqual(sent.count, 1);
    XCTAssertEqualObjects(sent[0].payload, mutation1.payload);
}

@end
