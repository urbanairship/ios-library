/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UAInAppAudienceHistorian+Internal.h"
#import "UATagGroupsMutation+Internal.h"
#import "UAChannel+Internal.h"
#import "UANamedUser+Internal.h"

@interface UATagGroupHistorianTest : UAAirshipBaseTest
@property(nonatomic, strong) UAInAppAudienceHistorian *historian;
@property(nonatomic, strong) id mockChannel;
@property(nonatomic, strong) id mockNamedUser;
@end

@implementation UATagGroupHistorianTest

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
                                                      userInfo:@{UAChannelUploadedTagGroupMutationNotificationMutationKey:mutation1,
                                                                 UAChannelUploadedTagGroupMutationNotificationDateKey:recent,
                                                                 UAChannelUploadedTagGroupMutationNotificationIdentifierKey:@"identifier"}];

    [[NSNotificationCenter defaultCenter] postNotificationName:UAChannelUploadedTagGroupMutationNotification
                                                        object:nil
                                                      userInfo:@{UAChannelUploadedTagGroupMutationNotificationMutationKey:mutation2,
                                                                 UAChannelUploadedTagGroupMutationNotificationDateKey:old,
                                                                 UAChannelUploadedTagGroupMutationNotificationIdentifierKey:@"identifier"}];

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
                                                      userInfo:@{UANamedUserUploadedTagGroupMutationNotificationMutationKey:mutation1,
                                                                 UANamedUserUploadedTagGroupMutationNotificationDateKey:date,
                                                                 UANamedUserUploadedTagGroupMutationNotificationIdentifierKey:@"nope!"}];

    // This should be included because the identifier matches
    [[NSNotificationCenter defaultCenter] postNotificationName:UANamedUserUploadedTagGroupMutationNotification
                                                        object:nil
                                                      userInfo:@{UANamedUserUploadedTagGroupMutationNotificationMutationKey:mutation2,
                                                                 UANamedUserUploadedTagGroupMutationNotificationDateKey:date,
                                                                 UANamedUserUploadedTagGroupMutationNotificationIdentifierKey:@"identifier"}];

    XCTAssertEqualObjects(@[mutation2], [self.historian tagHistoryNewerThan:date]);
}

@end
