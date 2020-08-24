/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UAInAppAudienceHistorian+Internal.h"
#import "UATagGroupsMutation+Internal.h"
#import "UAChannel+Internal.h"
#import "UANamedUser+Internal.h"

@interface UAInAppAudienceHistorianTest : UAAirshipBaseTest
@property(nonatomic, strong) UAInAppAudienceHistorian *historian;
@property(nonatomic, strong) id mockChannel;
@property(nonatomic, strong) id mockNamedUser;
@end

@implementation UAInAppAudienceHistorianTest

- (void)setUp {
    self.mockChannel = [self mockForClass:[UAChannel class]];
    self.mockNamedUser = [self mockForClass:[UANamedUser class]];

    self.historian = [UAInAppAudienceHistorian historianWithChannel:self.mockChannel
                                                          namedUser:self.mockNamedUser];
}

- (void)testTagHistory {
    UATagGroupsMutation *mutation1 = [UATagGroupsMutation mutationToSetTags:@[@"baz", @"boz"] group:@"group1"];
    UATagGroupsMutation *mutation2 = [UATagGroupsMutation mutationToSetTags:@[@"bleep", @"bloop"] group:@"group2"];

    NSDate *recent = [NSDate dateWithTimeIntervalSinceNow:-60];
    NSDate *old = [NSDate distantPast];

    [[NSNotificationCenter defaultCenter] postNotificationName:UAChannelUploadedTagGroupMutationNotification
                                                        object:nil
                                                      userInfo:@{UAChannelUploadedAudienceMutationNotificationMutationKey:mutation1,
                                                                 UAChannelUploadedAudienceMutationNotificationDateKey:recent,
                                                                 UAChannelUploadedAudienceMutationNotificationIdentifierKey:@"identifier"}];

    [[NSNotificationCenter defaultCenter] postNotificationName:UAChannelUploadedTagGroupMutationNotification
                                                        object:nil
                                                      userInfo:@{UAChannelUploadedAudienceMutationNotificationMutationKey:mutation2,
                                                                 UAChannelUploadedAudienceMutationNotificationDateKey:old,
                                                                 UAChannelUploadedAudienceMutationNotificationIdentifierKey:@"identifier"}];

    XCTAssertEqualObjects(@[mutation1], [self.historian tagHistoryNewerThan:recent]);
    XCTAssertEqualObjects((@[mutation1, mutation2]), [self.historian tagHistoryNewerThan:old]);
}

- (void)testTagHistoryIgnoresWrongNamedUser {
    [[[self.mockNamedUser stub] andReturn:@"identifier"] identifier];

    UATagGroupsMutation *mutation1 = [UATagGroupsMutation mutationToSetTags:@[@"baz", @"boz"] group:@"group1"];
    UATagGroupsMutation *mutation2 = [UATagGroupsMutation mutationToSetTags:@[@"bleep", @"bloop"] group:@"group2"];

    NSDate *date = [NSDate date];

    // This should be filtered out because the identifier is stale
    [[NSNotificationCenter defaultCenter] postNotificationName:UANamedUserUploadedTagGroupMutationNotification
                                                        object:nil
                                                      userInfo:@{UANamedUserUploadedAudienceMutationNotificationMutationKey:mutation1,
                                                                 UANamedUserUploadedAudienceMutationNotificationDateKey:date,
                                                                 UANamedUserUploadedAudienceMutationNotificationIdentifierKey:@"nope!"}];

    // This should be included because the identifier matches
    [[NSNotificationCenter defaultCenter] postNotificationName:UANamedUserUploadedTagGroupMutationNotification
                                                        object:nil
                                                      userInfo:@{UANamedUserUploadedAudienceMutationNotificationMutationKey:mutation2,
                                                                 UANamedUserUploadedAudienceMutationNotificationDateKey:date,
                                                                 UANamedUserUploadedAudienceMutationNotificationIdentifierKey:@"identifier"}];

    XCTAssertEqualObjects(@[mutation2], [self.historian tagHistoryNewerThan:date]);
}



- (void)testAttributeHistory {
    UAAttributeMutations *breakfastDrink = [UAAttributeMutations mutations];
    [breakfastDrink setString:@"coffee" forAttribute:@"breakfastDrink"];
    UAAttributePendingMutations *mutation1 = [UAAttributePendingMutations pendingMutationsWithMutations:breakfastDrink date:[[UADate alloc] init]];

    UAAttributeMutations *lunchDrink = [UAAttributeMutations mutations];
    [lunchDrink setString:@"Code Red" forAttribute:@"lunchDrink"];
    UAAttributePendingMutations *mutation2 = [UAAttributePendingMutations pendingMutationsWithMutations:lunchDrink date:[[UADate alloc] init]];


    NSDate *recent = [NSDate dateWithTimeIntervalSinceNow:-60];
    NSDate *old = [NSDate distantPast];

    [[NSNotificationCenter defaultCenter] postNotificationName:UAChannelUploadedAttributeMutationsNotification
                                                        object:nil
                                                      userInfo:@{UAChannelUploadedAudienceMutationNotificationMutationKey:mutation1,
                                                                 UAChannelUploadedAudienceMutationNotificationDateKey:recent,
                                                                 UAChannelUploadedAudienceMutationNotificationIdentifierKey:@"identifier"}];

    [[NSNotificationCenter defaultCenter] postNotificationName:UAChannelUploadedAttributeMutationsNotification
                                                        object:nil
                                                      userInfo:@{UAChannelUploadedAudienceMutationNotificationMutationKey:mutation2,
                                                                 UAChannelUploadedAudienceMutationNotificationDateKey:old,
                                                                 UAChannelUploadedAudienceMutationNotificationIdentifierKey:@"identifier"}];

    XCTAssertEqualObjects(@[mutation1], [self.historian attributeHistoryNewerThan:recent]);
    XCTAssertEqualObjects((@[mutation1, mutation2]), [self.historian attributeHistoryNewerThan:old]);
}

- (void)testAttributeHistoryIgnoresWrongNamedUser {
    [[[self.mockNamedUser stub] andReturn:@"identifier"] identifier];

    UAAttributeMutations *breakfastDrink = [UAAttributeMutations mutations];
    [breakfastDrink setString:@"coffee" forAttribute:@"breakfastDrink"];
    UAAttributePendingMutations *mutation1 = [UAAttributePendingMutations pendingMutationsWithMutations:breakfastDrink date:[[UADate alloc] init]];

    UAAttributeMutations *lunchDrink = [UAAttributeMutations mutations];
    [lunchDrink setString:@"Code Red" forAttribute:@"lunchDrink"];
    UAAttributePendingMutations *mutation2 = [UAAttributePendingMutations pendingMutationsWithMutations:lunchDrink date:[[UADate alloc] init]];

    NSDate *date = [NSDate date];

    // This should be filtered out because the identifier is stale
    [[NSNotificationCenter defaultCenter] postNotificationName:UANamedUserUploadedAttributeMutationsNotification
                                                        object:nil
                                                      userInfo:@{UANamedUserUploadedAudienceMutationNotificationMutationKey:mutation1,
                                                                 UANamedUserUploadedAudienceMutationNotificationDateKey:date,
                                                                 UANamedUserUploadedAudienceMutationNotificationIdentifierKey:@"nope!"}];

    // This should be included because the identifier matches
    [[NSNotificationCenter defaultCenter] postNotificationName:UANamedUserUploadedAttributeMutationsNotification
                                                        object:nil
                                                      userInfo:@{UANamedUserUploadedAudienceMutationNotificationMutationKey:mutation2,
                                                                 UANamedUserUploadedAudienceMutationNotificationDateKey:date,
                                                                 UANamedUserUploadedAudienceMutationNotificationIdentifierKey:@"identifier"}];

    XCTAssertEqualObjects(@[mutation2], [self.historian attributeHistoryNewerThan:date]);
}

@end
