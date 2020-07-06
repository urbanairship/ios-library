/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UATagGroupsMutationHistory+Internal.h"

@interface UATagGroupsMutationHistoryTest : UAAirshipBaseTest

@property(nonatomic, strong) UATagGroupsMutationHistory *channelMutationHistory;
@property(nonatomic, strong) UATagGroupsMutationHistory *namedUserMutationHistory;

@end

@implementation UATagGroupsMutationHistoryTest

- (void)setUp {
    [super setUp];
    self.channelMutationHistory = [UATagGroupsMutationHistory historyWithDataStore:self.dataStore keyStore:UATagGroupsChannelStoreKey];
    self.namedUserMutationHistory = [UATagGroupsMutationHistory historyWithDataStore:self.dataStore keyStore:UATagGroupsNamedUserStoreKey];
}

- (void)tearDown {
    [self.channelMutationHistory clearAll];
    [self.namedUserMutationHistory clearAll];
    [super tearDown];
}

- (void)testAddPendingMutation {
    UATagGroupsMutation *mutation = [UATagGroupsMutation mutationToAddTags:@[@"tag2"] group:@"group"];
    [self.channelMutationHistory addPendingMutation:mutation];

    UATagGroupsMutation *fromHistory = [self.channelMutationHistory popPendingMutation];
    XCTAssertEqualObjects(mutation.payload, fromHistory.payload);
}

- (void)testAddingPendingMutationsDoesntCollapseMutations {
    UATagGroupsMutation *add = [UATagGroupsMutation mutationToAddTags:@[@"tag1"] group:@"group"];
    UATagGroupsMutation *remove = [UATagGroupsMutation mutationToRemoveTags:@[@"tag2", @"tag1"] group:@"group"];

    [self.channelMutationHistory addPendingMutation:remove];
    [self.channelMutationHistory addPendingMutation:add];

    UATagGroupsMutation *fromHistory = [self.channelMutationHistory popPendingMutation];

    NSDictionary *expected = @{ @"remove": @{ @"group": @[@"tag2", @"tag1"] }};
    XCTAssertEqualObjects(expected, fromHistory.payload);

    fromHistory = [self.channelMutationHistory popPendingMutation];
    
    expected = @{ @"add": @{ @"group": @[@"tag1"] }};
    XCTAssertEqualObjects(expected, fromHistory.payload);
}

- (void)testCollapsePendingMutations {
    UATagGroupsMutation *add = [UATagGroupsMutation mutationToAddTags:@[@"tag1"] group:@"group"];
    UATagGroupsMutation *remove = [UATagGroupsMutation mutationToRemoveTags:@[@"tag2", @"tag1"] group:@"group"];

    [self.channelMutationHistory addPendingMutation:remove];
    [self.channelMutationHistory addPendingMutation:add];
    [self.channelMutationHistory collapsePendingMutations];
    
    UATagGroupsMutation *fromHistory = [self.channelMutationHistory popPendingMutation];
    
    NSDictionary *expected = @{ @"remove": @{ @"group": @[@"tag2"] }, @"add": @{ @"group": @[@"tag1"] } };
    XCTAssertEqualObjects(expected, fromHistory.payload);
}

- (void)testPeekPendingMutation {
    XCTAssertNil([self.channelMutationHistory peekPendingMutation]);
    
    UATagGroupsMutation *add = [UATagGroupsMutation mutationToAddTags:@[@"tag1"] group:@"group"];
    [self.channelMutationHistory addPendingMutation:add];
    
    UATagGroupsMutation *peekedMutation = [self.channelMutationHistory peekPendingMutation];
    XCTAssertNotNil(peekedMutation);
    UATagGroupsMutation *poppedMutation = [self.channelMutationHistory popPendingMutation];
    XCTAssertNotNil(poppedMutation);
    XCTAssertEqualObjects(peekedMutation.payload, poppedMutation.payload);
    XCTAssertNil([self.channelMutationHistory popPendingMutation]);
}

- (void)testPopPendingMutation {
    XCTAssertNil([self.channelMutationHistory popPendingMutation]);

    UATagGroupsMutation *add = [UATagGroupsMutation mutationToAddTags:@[@"tag1"] group:@"group"];
    [self.channelMutationHistory addPendingMutation:add];

    XCTAssertNotNil([self.channelMutationHistory popPendingMutation]);
    XCTAssertNil([self.channelMutationHistory popPendingMutation]);
}

- (void)testMigration {
    NSDictionary *oldAddTags = @{ @"group1": @[@"tag1"] };
    [self.dataStore setObject:oldAddTags forKey:@"UAPushAddTagGroups"];

    NSDictionary *oldRemoveTags = @{ @"group2": @[@"tag2"] };
    [self.dataStore setObject:oldRemoveTags forKey:@"UAPushRemoveTagGroups"];

    UATagGroupsMutation *oldMutation = [UATagGroupsMutation mutationToAddTags:@[@"foo", @"bar"] group:@"group1"];
    NSData *encodedMutations = [NSKeyedArchiver archivedDataWithRootObject:@[oldMutation]];
    [self.dataStore setObject:encodedMutations forKey:@"UAPushTagGroupsMutations"];

    UATagGroupsMutationHistory *channelTagGroupsMutationHistory = [UATagGroupsMutationHistory historyWithDataStore:self.dataStore keyStore:UATagGroupsChannelStoreKey];

    UATagGroupsMutation *oldAddRemoveFromHistory = [channelTagGroupsMutationHistory popPendingMutation];
    NSDictionary *expected = @{ @"add": @{ @"group1": @[@"tag1"] }, @"remove": @{ @"group2": @[@"tag2"] } };
    XCTAssertEqualObjects(expected, oldAddRemoveFromHistory.payload);

    UATagGroupsMutation *oldMutationFromHistory = [channelTagGroupsMutationHistory popPendingMutation];
    XCTAssertEqualObjects(oldMutation.payload, oldMutationFromHistory.payload);
}

- (void)testApplyMutations {
    UATagGroups *tagGroups = [UATagGroups tagGroupsWithTags:@{ @"group1": @[@"tag1", @"tag2"], @"group2" : @[@"tag3", @"tag4"] }];

    UATagGroupsMutation *mutation1 = [UATagGroupsMutation mutationToAddTags:@[@"foo", @"bar"] group:@"group1"];
    UATagGroupsMutation *mutation2 = [UATagGroupsMutation mutationToRemoveTags:@[@"tag3"] group:@"group2"];

    [self.channelMutationHistory addPendingMutation:mutation1];
    [self.channelMutationHistory addPendingMutation:mutation2];

    NSTimeInterval maxAge = 60 * 60;

    UATagGroupsMutation *mutation3 = [UATagGroupsMutation mutationToSetTags:@[@"baz", @"boz"] group:@"group3"];
    UATagGroupsMutation *mutation4 = [UATagGroupsMutation mutationToSetTags:@[@"bleep", @"bloop"] group:@"group4"];

    NSDate *recent = [NSDate dateWithTimeIntervalSinceNow:-(maxAge/2)];
    NSDate *old = [NSDate distantPast];

    [self.channelMutationHistory addSentMutation:mutation3 date:recent];
    [self.channelMutationHistory addSentMutation:mutation4 date:old];

    UATagGroups *newTagGroups = [self.channelMutationHistory applyHistory:tagGroups maxAge:maxAge];

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

    [self.channelMutationHistory addSentMutation:mutation1 date:recent];
    [self.channelMutationHistory addSentMutation:mutation2 date:old];

    NSArray<UATagGroupsMutation *> *sent = [self.channelMutationHistory sentMutationsWithMaxAge:maxAge];

    XCTAssertEqual(sent.count, 1);
    XCTAssertEqualObjects(sent[0].payload, mutation1.payload);
}

@end
