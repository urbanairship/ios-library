/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UAInAppAudienceHistorian+Internal.h"
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
    UATagGroupUpdate *tagUpdate1 = [[UATagGroupUpdate alloc] initWithGroup:@"group1" tags:@[@"baz", @"boz"] type:UATagGroupUpdateTypeSet];
    UATagGroupUpdate *tagUpdate2 = [[UATagGroupUpdate alloc] initWithGroup:@"group2" tags:@[@"bleep", @"bloop"] type:UATagGroupUpdateTypeSet];
    
    NSDate *recent = [NSDate dateWithTimeIntervalSinceNow:-60];
    NSDate *old = [NSDate distantPast];

    self.testDate.dateOverride = recent;
    [[NSNotificationCenter defaultCenter] postNotificationName:UAChannel.audienceUpdatedEvent
                                                        object:nil
                                                      userInfo:@{ UAChannel.audienceTagsKey: @[tagUpdate1] }];

    self.testDate.dateOverride = old;
    [[NSNotificationCenter defaultCenter] postNotificationName:UAChannel.audienceUpdatedEvent
                                                        object:nil
                                                      userInfo:@{ UAChannel.audienceTagsKey: @[tagUpdate2] }];

    XCTAssertEqualObjects(@[tagUpdate1], [self.historian tagHistoryNewerThan:recent]);

    NSArray *combined = @[tagUpdate1, tagUpdate2];
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

    UAAttributeUpdate *breakfastDrink = [[UAAttributeUpdate alloc] initWithAttribute:@"breakfastDrink"
                                                                            type:UAAttributeUpdateTypeSet
                                                                           value:@"coffee"
                                                                            date:recent];

    UAAttributeUpdate *lunchDrink = [[UAAttributeUpdate alloc] initWithAttribute:@"lunchDrink"
                                                                            type:UAAttributeUpdateTypeSet
                                                                           value:@"code-red"
                                                                            date:old];
    
    self.testDate.dateOverride = recent;
    [[NSNotificationCenter defaultCenter] postNotificationName:UAChannel.audienceUpdatedEvent
                                                        object:nil
                                                      userInfo:@{UAChannel.audienceAttributesKey: @[breakfastDrink]}];

    self.testDate.dateOverride = old;

    [[NSNotificationCenter defaultCenter] postNotificationName:UAContact.audienceUpdatedEvent
                                                        object:nil
                                                      userInfo:@{UAContact.attributesKey: @[lunchDrink]}];

    XCTAssertEqualObjects(@[breakfastDrink], [self.historian attributeHistoryNewerThan:recent]);
    
    NSArray *combined = @[breakfastDrink, lunchDrink];
    XCTAssertEqualObjects(combined, [self.historian attributeHistoryNewerThan:old]);
}

@end
