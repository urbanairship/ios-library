/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UAInAppAudienceHistorian+Internal.h"
#import "UAChannel+Internal.h"
#import "AirshipTests-Swift.h"

@import AirshipCore;

@interface UAInAppAudienceHistorianTest : UAAirshipBaseTest
@property(nonatomic, strong) UAInAppAudienceHistorian *historian;
@property(nonatomic, strong) id mockChannel;
@property(nonatomic, strong) id mockContact;
@property(nonatomic, strong) UATestDate *testDate;
@end

@implementation UAInAppAudienceHistorianTest

- (void)setUp {
    self.mockChannel = [self mockForClass:[UAChannel class]];
    self.mockContact = [self mockForClass:[UAContact class]];
    self.testDate = [[UATestDate alloc] init];

    self.historian = [UAInAppAudienceHistorian historianWithChannel:self.mockChannel
                                                          contact:self.mockContact
                                                               date:self.testDate];
}

- (void)testTagHistory {
    UATagGroupsMutation *mutation1 = [UATagGroupsMutation mutationToSetTags:@[@"baz", @"boz"] group:@"group1"];
    UATagGroupsMutation *mutation2 = [UATagGroupsMutation mutationToSetTags:@[@"bleep", @"bloop"] group:@"group2"];

    NSDate *recent = [NSDate dateWithTimeIntervalSinceNow:-60];
    NSDate *old = [NSDate distantPast];

    self.testDate.dateOverride = recent;
    [[NSNotificationCenter defaultCenter] postNotificationName:UAChannelUploadedTagGroupMutationNotification
                                                        object:nil
                                                      userInfo:@{UAChannelUploadedAudienceMutationNotificationMutationKey:mutation1}];

    self.testDate.dateOverride = old;
    [[NSNotificationCenter defaultCenter] postNotificationName:UAChannelUploadedTagGroupMutationNotification
                                                        object:nil
                                                      userInfo:@{UAChannelUploadedAudienceMutationNotificationMutationKey:mutation2}];

    XCTAssertEqualObjects(mutation1.tagGroupUpdates, [self.historian tagHistoryNewerThan:recent]);

    
    NSMutableArray *combined = [NSMutableArray array];
    [combined addObjectsFromArray:mutation1.tagGroupUpdates];
    [combined addObjectsFromArray:mutation2.tagGroupUpdates];
    XCTAssertEqualObjects(combined, [self.historian tagHistoryNewerThan:old]);
}

- (void)testContactHistoryClearedOnChange {
    NSDate *date = [NSDate date];
    self.testDate.dateOverride = date;
    
    UATagGroupUpdate *tagUpdate = [[UATagGroupUpdate alloc] initWithGroup:@"some-group" tags:@[@"tags!"] type:UATagGroupUpdateTypeAdd];
    UAAttributeUpdate *attributeUpdate = [[UAAttributeUpdate alloc] initWithAttribute:@"lunchDrink"
                                                                            type:UAAttributeUpdateTypeSet
                                                                           value:@"code-red"
                                                                            date:self.testDate.now];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:UAContact.audienceUpdatedEvent
                                                        object:nil
                                                      userInfo:@{ UAContact.attributesKey: @[attributeUpdate],
                                                                  UAContact.tagsKey: @[tagUpdate] }];

    XCTAssertEqualObjects(@[tagUpdate], [self.historian tagHistoryNewerThan:date]);
    XCTAssertEqualObjects(@[attributeUpdate], [self.historian attributeHistoryNewerThan:date]);
    
    [[NSNotificationCenter defaultCenter] postNotificationName:UAContact.contactChangedEvent
                                                        object:nil
                                                      userInfo:nil];

    XCTAssertEqualObjects(@[], [self.historian tagHistoryNewerThan:date]);
    XCTAssertEqualObjects(@[], [self.historian attributeHistoryNewerThan:date]);
}

- (void)testAttributeHistory {
    NSDate *recent = [NSDate dateWithTimeIntervalSinceNow:-60];
    NSDate *old = [NSDate distantPast];

    UAAttributeMutations *breakfastDrink = [UAAttributeMutations mutations];
    [breakfastDrink setString:@"coffee" forAttribute:@"breakfastDrink"];
    UAAttributePendingMutations *mutation1 = [UAAttributePendingMutations pendingMutationsWithMutations:breakfastDrink date:[[UADate alloc] init]];

    UAAttributeUpdate *lunchDrink = [[UAAttributeUpdate alloc] initWithAttribute:@"lunchDrink"
                                                                            type:UAAttributeUpdateTypeSet
                                                                           value:@"code-red"
                                                                            date:self.testDate.now];
    
    self.testDate.dateOverride = recent;
    [[NSNotificationCenter defaultCenter] postNotificationName:UAChannelUploadedAttributeMutationsNotification
                                                        object:nil
                                                      userInfo:@{UAChannelUploadedAudienceMutationNotificationMutationKey:mutation1}];

    self.testDate.dateOverride = old;

    [[NSNotificationCenter defaultCenter] postNotificationName:UAContact.audienceUpdatedEvent
                                                        object:nil
                                                      userInfo:@{UAContact.attributesKey: @[lunchDrink]}];

    XCTAssertEqualObjects(mutation1.attributeUpdates, [self.historian attributeHistoryNewerThan:recent]);
    
    NSMutableArray *combined = [NSMutableArray array];
    [combined addObjectsFromArray:mutation1.attributeUpdates];
    [combined addObject:lunchDrink];
    
    XCTAssertEqualObjects(combined, [self.historian attributeHistoryNewerThan:old]);
}

@end
