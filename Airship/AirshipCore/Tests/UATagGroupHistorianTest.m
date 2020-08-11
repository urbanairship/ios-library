/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UATagGroupHistorian.h"
#import "UATagGroupsMutation+Internal.h"
#import "UAChannel+Internal.h"
#import "UANamedUser+Internal.h"
#import "UALocaleManager+Internal.h"

@interface UATagGroupHistorian()

- (NSArray<UATagGroupsMutation *> *)sentMutationsWithMaxAge:(NSTimeInterval)maxAge;

@end

@interface UATagGroupHistorianTest : UAAirshipBaseTest

@property(nonatomic, strong) UATagGroupHistorian *tagGroupHistorian;
@property(nonatomic, strong) id mockChannel;
@property(nonatomic, strong) id mockNamedUser;

@end

@implementation UATagGroupHistorianTest

- (void)setUp {
    self.mockChannel = [self mockForClass:[UAChannel class]];
    self.mockNamedUser = [self mockForClass:[UANamedUser class]];

    self.tagGroupHistorian = [[UATagGroupHistorian alloc] initTagGroupHistorianWithChannel:self.mockChannel namedUser:self.mockNamedUser];
}
- (void)testApplyMutations {
    UATagGroups *tagGroups = [UATagGroups tagGroupsWithTags:@{ @"group1": @[@"tag1", @"tag2"], @"group2" : @[@"tag3", @"tag4"] }];

    UATagGroupsMutation *mutation1 = [UATagGroupsMutation mutationToAddTags:@[@"foo", @"bar"] group:@"group1"];
    UATagGroupsMutation *mutation2 = [UATagGroupsMutation mutationToRemoveTags:@[@"tag3"] group:@"group2"];

    [[[self.mockChannel stub] andReturn:@[mutation1, mutation2]] pendingTagGroups];

    NSTimeInterval maxAge = 60 * 60;

    UATagGroupsMutation *mutation3 = [UATagGroupsMutation mutationToSetTags:@[@"baz", @"boz"] group:@"group3"];
    UATagGroupsMutation *mutation4 = [UATagGroupsMutation mutationToSetTags:@[@"bleep", @"bloop"] group:@"group4"];

    NSDate *recent = [NSDate dateWithTimeIntervalSinceNow:-(maxAge/2)];
    NSDate *old = [NSDate distantPast];

    [[NSNotificationCenter defaultCenter] postNotificationName:UAChannelUploadedTagGroupMutationNotification
                                                        object:nil
                                                      userInfo:@{UAChannelUploadedTagGroupMutationNotificationMutationKey:mutation3,
                                                                 UAChannelUploadedTagGroupMutationNotificationDateKey:recent,
                                                                 UAChannelUploadedTagGroupMutationNotificationIdentifierKey:@"identifier"}];

    [[NSNotificationCenter defaultCenter] postNotificationName:UAChannelUploadedTagGroupMutationNotification
                                                        object:nil
                                                      userInfo:@{UAChannelUploadedTagGroupMutationNotificationMutationKey:mutation4,
                                                                 UAChannelUploadedTagGroupMutationNotificationDateKey:old,
                                                                 UAChannelUploadedTagGroupMutationNotificationIdentifierKey:@"identifier"}];

    UATagGroups *newTagGroups = [self.tagGroupHistorian applyHistory:tagGroups maxAge:maxAge];

    UATagGroups *expectedTagGroups = [UATagGroups tagGroupsWithTags:@{ @"group1" : @[@"tag1", @"tag2", @"foo", @"bar"],
                                                                       @"group2" : @[@"tag4"],
                                                                       @"group3" : @[@"baz", @"boz"] }];

    XCTAssertEqualObjects(newTagGroups, expectedTagGroups);
}

- (void)testSentMutationsIgnoresWrongNamedUserID {
    [[[self.mockNamedUser stub] andReturn:@"identifier"] identifier];

    UATagGroupsMutation *mutation1 = [UATagGroupsMutation mutationToSetTags:@[@"baz", @"boz"] group:@"group1"];
    UATagGroupsMutation *mutation2 = [UATagGroupsMutation mutationToSetTags:@[@"bleep", @"bloop"] group:@"group2"];

    NSDate *date = [NSDate date];

    // This should be filtered out because the identifier is stale
    [[NSNotificationCenter defaultCenter] postNotificationName:UANamedUserUploadedTagGroupMutationNotification
                                                        object:nil
                                                      userInfo:@{UANamedUserUploadedTagGroupMutationNotificationMutationKey:mutation1,
                                                                 UANamedUserUploadedTagGroupMutationNotificationDateKey:date,
                                                                 UANamedUserUploadedTagGroupMutationNotificationIdentifierKey:@"nope!"}];

    // This should be included because the identifier matches
    [[NSNotificationCenter defaultCenter] postNotificationName:UANamedUserUploadedTagGroupMutationNotification
                                                        object:nil
                                                      userInfo:@{UANamedUserUploadedTagGroupMutationNotificationMutationKey:mutation2,
                                                                 UANamedUserUploadedTagGroupMutationNotificationDateKey:date,
                                                                 UANamedUserUploadedTagGroupMutationNotificationIdentifierKey:@"identifier"}];


    NSArray<UATagGroupsMutation *> *sent = [self.tagGroupHistorian sentMutationsWithMaxAge:60];

    XCTAssertEqual(sent.count, 1);
    XCTAssertEqualObjects(sent[0].payload, mutation2.payload);
}

- (void)testSentMutationsCleansOldRecords {
    UATagGroupsMutation *mutation1 = [UATagGroupsMutation mutationToSetTags:@[@"baz", @"boz"] group:@"group3"];
    UATagGroupsMutation *mutation2 = [UATagGroupsMutation mutationToSetTags:@[@"bleep", @"bloop"] group:@"group4"];

    NSTimeInterval maxAge = 60 * 60;

    NSDate *recent = [NSDate dateWithTimeIntervalSinceNow:-(maxAge/2)];
    NSDate *old = [NSDate distantPast];

    [[NSNotificationCenter defaultCenter] postNotificationName:UAChannelUploadedTagGroupMutationNotification
                                                        object:nil
                                                      userInfo:@{UAChannelUploadedTagGroupMutationNotificationMutationKey:mutation1,
                                                                 UAChannelUploadedTagGroupMutationNotificationDateKey:recent,
                                                                 UAChannelUploadedTagGroupMutationNotificationIdentifierKey:@"identifier"}];

    [[NSNotificationCenter defaultCenter] postNotificationName:UAChannelUploadedTagGroupMutationNotification
                                                        object:nil
                                                      userInfo:@{UAChannelUploadedTagGroupMutationNotificationMutationKey:mutation2,
                                                                 UAChannelUploadedTagGroupMutationNotificationDateKey:old,
                                                                 UAChannelUploadedTagGroupMutationNotificationIdentifierKey:@"identifier"}];

    NSArray<UATagGroupsMutation *> *sent = [self.tagGroupHistorian sentMutationsWithMaxAge:maxAge];

    XCTAssertEqual(sent.count, 1);
    XCTAssertEqualObjects(sent[0].payload, mutation1.payload);
}

@end
