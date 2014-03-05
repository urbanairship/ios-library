/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import <OCMock/OCMConstraint.h>
#import "UAPush+Internal.h"
#import "UADeviceAPIClient.h"
#import "UAirship.h"
#import "UAAnalytics.h"
#import "UAirship+Internal.h"
#import "UAActionRunner.h"
#import "UAActionRegistrar+Internal.h"
#import "UAUtils.h"
#import "UAUser.h"
#import "UAChannelRegistrationPayload.h"
#import "UADeviceRegistrar.h"
#import "UAEvent.h"


@interface UAPushTest : XCTestCase
@property(nonatomic, strong) id mockedApplication;
@property(nonatomic, strong) id mockedDeviceRegistrar;
@property(nonatomic, strong) id mockedAirshipClass;
@property(nonatomic, strong) id mockedAnalytics;
@property(nonatomic, strong) id mockedPushDelegate;
@property(nonatomic, strong) id mockRegistrationDelegate;
@property(nonatomic, strong) id mockActionRunner;
@property(nonatomic, strong) id mockUAUtils;
@property(nonatomic, strong) id mockUAUser;

@end

@implementation UAPushTest

NSString *validDeviceToken = @"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
NSDictionary *notification;
- (void)setUp {
    [super setUp];

    notification = @{ @"aps":
                          @{ @"alert": @"sample alert!", @"badge": @2, @"sound": @"cat" },
                      @"someActionKey": @"someActionValue"
                    };

    // Set up a mocked application
    self.mockedApplication = [OCMockObject niceMockForClass:[UIApplication class]];
    [[[self.mockedApplication stub] andReturn:self.mockedApplication] sharedApplication];

    // Set up a mocked device api client
    self.mockedDeviceRegistrar = [OCMockObject partialMockForObject:[UAPush shared].deviceRegistrar];

    self.mockedAnalytics = [OCMockObject niceMockForClass:[UAAnalytics class]];

    self.mockedAirshipClass =[OCMockObject niceMockForClass:[UAirship class]];
    [[[self.mockedAirshipClass stub] andReturn:self.mockedAirshipClass] shared];
    [[[self.mockedAirshipClass stub] andReturn:self.mockedAnalytics] analytics];

    self.mockedPushDelegate = [OCMockObject niceMockForProtocol:@protocol(UAPushNotificationDelegate)];
    [UAPush shared].pushNotificationDelegate = self.mockedPushDelegate;

    self.mockRegistrationDelegate = [OCMockObject mockForProtocol:@protocol(UARegistrationDelegate)];

    self.mockActionRunner = [OCMockObject mockForClass:[UAActionRunner class]];

    self.mockUAUtils = [OCMockObject niceMockForClass:[UAUtils class]];
    [[[self.mockUAUtils stub] andReturn:@"someDeviceID"] deviceID];

    self.mockUAUser = [OCMockObject niceMockForClass:[UAUser class]];
    [[[self.mockUAUser stub] andReturn:self.mockUAUser] defaultUser];
    [[[self.mockUAUser stub] andReturn:@"someUser"] username];


    [UAPush shared].registrationDelegate = self.mockRegistrationDelegate;
}

- (void)tearDown {
    [super tearDown];
    [UAPush shared].pushNotificationDelegate = nil;
    [UAPush shared].registrationDelegate = nil;

    [self.mockedApplication stopMocking];
    [self.mockedDeviceRegistrar stopMocking];
    [self.mockedAnalytics stopMocking];
    [self.mockedAirshipClass stopMocking];
    [self.mockedPushDelegate stopMocking];
    [self.mockRegistrationDelegate stopMocking];
    [self.mockActionRunner stopMocking];
    [self.mockUAUtils stopMocking];
    [self.mockUAUser stopMocking];
}

- (void)testSetDeviceToken {

    [UAPush shared].deviceToken = nil;

    [UAPush shared].deviceToken = @"invalid characters";

    XCTAssertNil([UAPush shared].deviceToken, @"setDeviceToken should ignore device tokens with invalid characters.");


    [UAPush shared].deviceToken = validDeviceToken;
    XCTAssertEqualObjects(validDeviceToken, [UAPush shared].deviceToken, @"setDeviceToken should set tokens with valid characters");

    [UAPush shared].deviceToken = nil;
    XCTAssertNil([UAPush shared].deviceToken,
                          @"setDeviceToken should allow a nil device token.");

    [UAPush shared].deviceToken = @"";
    XCTAssertEqualObjects(@"", [UAPush shared].deviceToken,
                 @"setDeviceToken should do nothing to an empty string");
}

- (void)testAutoBadgeEnabled {
    [UAPush shared].autobadgeEnabled = true;
    XCTAssertTrue([UAPush shared].autobadgeEnabled, @"autobadgeEnabled should be enabled when set to YES");
    XCTAssertTrue([[NSUserDefaults standardUserDefaults] boolForKey:UAPushBadgeSettingsKey],
                  @"autobadgeEnabled should be stored in standardUserDefaults");

    [UAPush shared].autobadgeEnabled = NO;
    XCTAssertFalse([UAPush shared].autobadgeEnabled, @"autobadgeEnabled should be disabled when set to NO");
    XCTAssertFalse([[NSUserDefaults standardUserDefaults] boolForKey:UAPushBadgeSettingsKey],
                   @"autobadgeEnabled should be stored in standardUserDefaults");
}

- (void)testAlias {
    [UAPush shared].alias = @"some-alias";
    XCTAssertEqualObjects(@"some-alias", [UAPush shared].alias, @"alias is not being set correctly");
    XCTAssertEqualObjects(@"some-alias", [[NSUserDefaults standardUserDefaults] stringForKey:UAPushAliasSettingsKey],
                          @"alias should be stored in standardUserDefaults");

    [UAPush shared].alias = nil;
    XCTAssertNil([UAPush shared].alias, @"alias should be able to be cleared");
    XCTAssertNil([[NSUserDefaults standardUserDefaults] stringForKey:UAPushAliasSettingsKey],
                 @"alias should be able to be cleared in standardUserDefaults");
}

- (void)testTags {
    NSArray *tags = @[@"tag-one", @"tag-two"];
    [UAPush shared].tags = tags;

    XCTAssertEqual((NSUInteger)2, [UAPush shared].tags.count, @"should of added 2 tags");
    XCTAssertEqualObjects(tags, [UAPush shared].tags, @"tags are not stored correctly");
    XCTAssertEqualObjects([[NSUserDefaults standardUserDefaults] valueForKey:UAPushTagsSettingsKey], [UAPush shared].tags,
                          @"tags are not stored correctly in standardUserDefaults");

    [UAPush shared].tags = nil;
    XCTAssertEqual((NSUInteger)0, [UAPush shared].tags.count, @"tags should return an empty array even when set to nil");
    XCTAssertEqual((NSUInteger)0, [[[NSUserDefaults standardUserDefaults] valueForKey:UAPushTagsSettingsKey] count],
                   @"tags are not being cleared in standardUserDefaults");
}

- (void)testAddTagsToCurrentDevice {
    [UAPush shared].tags = nil;

    [[UAPush shared] addTagsToCurrentDevice:@[@"tag-one", @"tag-two"]];
    XCTAssertEqualObjects([NSSet setWithArray:(@[@"tag-one", @"tag-two"])], [NSSet setWithArray:[UAPush shared].tags],
                          @"Add tags to current device fails when no existing tags exist");

    // Try to add same tags again
    [[UAPush shared] addTagsToCurrentDevice:@[@"tag-one", @"tag-two"]];
    XCTAssertEqual((NSUInteger)2, [UAPush shared].tags.count, @"Add tags should not add duplicate tags");


    // Try to add a new set of tags, with one of the tags being unique
    [[UAPush shared] addTagsToCurrentDevice:@[@"tag-one", @"tag-three"]];

    XCTAssertEqual((NSUInteger)3, [UAPush shared].tags.count,
                   @"Add tags should add unique tags even if some of them are duplicate");

    XCTAssertEqualObjects([NSSet setWithArray:(@[@"tag-one", @"tag-two", @"tag-three"])], [NSSet setWithArray:[UAPush shared].tags],
                          @"Add tags should add unique tags even if some of them are duplicate");

    // Try to add an nil set of tags
    XCTAssertNoThrow([[UAPush shared] addTagsToCurrentDevice:nil],
                     @"Should not throw when adding a nil set of tags");

    // Try to add an nil set of tags
    XCTAssertNoThrow([[UAPush shared] addTagsToCurrentDevice:[NSArray array]],
                     @"Should not throw when adding an empty tag array");
}

- (void)testAddTagToCurrentDevice {
    [UAPush shared].tags = nil;

    [[UAPush shared] addTagToCurrentDevice:@"tag-one"];
    XCTAssertEqualObjects((@[@"tag-one"]), [UAPush shared].tags,
                          @"Add tag to current device fails when no existing tags exist");

    // Try to add same tag again
    [[UAPush shared] addTagToCurrentDevice:@"tag-one"];
    XCTAssertEqual((NSUInteger)1, [UAPush shared].tags.count, @"Add tag should not add duplicate tags");

    // Add a new tag
    [[UAPush shared] addTagToCurrentDevice:@"tag-two"];
    XCTAssertEqualObjects((@[@"tag-one", @"tag-two"]), [UAPush shared].tags,
                          @"Adding another tag to tags fails");

    // Try to add an nil tag
    XCTAssertThrows([[UAPush shared] addTagToCurrentDevice:nil],
                    @"Should throw when adding a nil tag");
}

- (void)testRemoveTagFromCurrentDevice {
    [UAPush shared].tags = nil;
    XCTAssertNoThrow([[UAPush shared] removeTagFromCurrentDevice:@"some-tag"],
                     @"Should not throw when removing a tag when tags are empty");

    [UAPush shared].tags = @[@"some-tag", @"some-other-tag"];
    XCTAssertNoThrow([[UAPush shared] removeTagFromCurrentDevice:@"some-not-found-tag"],
                     @"Should not throw when removing a tag that does not exist");

    [[UAPush shared] removeTagFromCurrentDevice:@"some-tag"];
    XCTAssertEqualObjects((@[@"some-other-tag"]), [UAPush shared].tags,
                          @"Remove tag from device should actually remove the tag");

    XCTAssertThrows([[UAPush shared] removeTagFromCurrentDevice:nil],
                    @"Should throw when removing a nil tag");
}

- (void)testRemoveTagsFromCurrentDevice {
    [UAPush shared].tags = nil;
    XCTAssertNoThrow([[UAPush shared] removeTagsFromCurrentDevice:@[@"some-tag"]],
                     @"Should not throw when removing tags when current tags are empty");

    [UAPush shared].tags = @[@"some-tag", @"some-other-tag"];
    XCTAssertNoThrow([[UAPush shared] removeTagsFromCurrentDevice:@[@"some-not-found-tag"]],
                     @"Should not throw when removing tags that do not exist");

    [[UAPush shared] removeTagsFromCurrentDevice:@[@"some-tag"]];
    XCTAssertEqualObjects((@[@"some-other-tag"]), [UAPush shared].tags,
                          @"Remove tags from device should actually remove the tag");

    XCTAssertNoThrow([[UAPush shared] removeTagsFromCurrentDevice:nil],
                     @"Should throw when removing a nil set of tags");
}

- (void)testPushEnabledToYes {
    [UAPush shared].pushEnabled = NO;

    // Make sure push is set to NO
    XCTAssertFalse([UAPush shared].pushEnabled, @"pushEnabled should default to NO");

    // Set the notificationTypes so we know what to expect when it registers
    [UAPush shared].notificationTypes = UIRemoteNotificationTypeAlert;

    [[self.mockedApplication expect] registerForRemoteNotificationTypes:UIRemoteNotificationTypeAlert];

    [UAPush shared].pushEnabled = YES;

    XCTAssertTrue([UAPush shared].pushEnabled,
                  @"pushEnabled should be enabled when set to YES");

    XCTAssertTrue([[NSUserDefaults standardUserDefaults] boolForKey:UAPushEnabledSettingsKey],
                  @"pushEnabled should be stored in standardUserDefaults");

    XCTAssertNoThrow([self.mockedApplication verify],
                     @"pushEnabled should register for remote notifications");
}

- (void)testPushEnabledToNo {
    [UAPush shared].deviceToken = validDeviceToken;
    [UAPush shared].pushEnabled = YES;

    // Add a device token so we get a device api callback
    [[self.mockedDeviceRegistrar expect] registerPushDisabledWithChannelID:OCMOCK_ANY
                                                           channelLocation:OCMOCK_ANY
                                                               withPayload:OCMOCK_ANY
                                                                forcefully:NO];

    [[self.mockedApplication expect] registerForRemoteNotificationTypes:UIRemoteNotificationTypeNone];


    [UAPush shared].pushEnabled = NO;

    XCTAssertFalse([UAPush shared].pushEnabled,
                   @"pushEnabled should be disabled when set to NO");

    XCTAssertFalse([[NSUserDefaults standardUserDefaults] boolForKey:UAPushEnabledSettingsKey],
                   @"pushEnabled should be stored in standardUserDefaults");

    XCTAssertNoThrow([self.mockedApplication verify],
                     @"pushEnabled should unregister for remote notifications");

    XCTAssertNoThrow([self.mockedDeviceRegistrar verify],
                     @"pushEnabled should make unregister with the device api client");
}

- (void)testSetQuietTime {
    [[UAPush shared] setQuietTimeStartHour:12 startMinute:30 endHour:14 endMinute:58];

    NSDictionary *quietTime = [UAPush shared].quietTime;
    XCTAssertEqualObjects(@"12:30", [quietTime valueForKey:UAPushQuietTimeStartKey],
                          @"Quiet time start is not set correctly");

    XCTAssertEqualObjects(@"14:58", [quietTime valueForKey:UAPushQuietTimeEndKey],
                          @"Quiet time end is not set correctly");

    // Change the time zone
    [UAPush shared].timeZone = [NSTimeZone timeZoneForSecondsFromGMT:-3600*3];

    // Make sure the hour and minutes are still the same
    quietTime = [UAPush shared].quietTime;
    XCTAssertEqualObjects(@"12:30", [quietTime valueForKey:UAPushQuietTimeStartKey],
                          @"Quiet time start is not set correctly");

    XCTAssertEqualObjects(@"14:58", [quietTime valueForKey:UAPushQuietTimeEndKey],
                          @"Quiet time end is not set correctly");


    // Try to set it to an invalid start hour
    [[UAPush shared] setQuietTimeStartHour:24 startMinute:30 endHour:14 endMinute:58];

    // Make sure the hour and minutes are still the same
    quietTime = [UAPush shared].quietTime;
    XCTAssertEqualObjects(@"12:30", [quietTime valueForKey:UAPushQuietTimeStartKey],
                          @"Quiet time start is not set correctly");

    XCTAssertEqualObjects(@"14:58", [quietTime valueForKey:UAPushQuietTimeEndKey],
                          @"Quiet time end is not set correctly");

    // Try to set it to an invalid end minute
    [[UAPush shared] setQuietTimeStartHour:12 startMinute:30 endHour:14 endMinute:60];

    // Make sure the hour and minutes are still the same
    quietTime = [UAPush shared].quietTime;
    XCTAssertEqualObjects(@"12:30", [quietTime valueForKey:UAPushQuietTimeStartKey],
                          @"Quiet time start is not set correctly");

    XCTAssertEqualObjects(@"14:58", [quietTime valueForKey:UAPushQuietTimeEndKey],
                          @"Quiet time end is not set correctly");
}

- (void)testSetQuietTimeDeprecated {
    NSDate *start = [NSDate dateWithTimeIntervalSince1970:60]; // 0:01 GMT
    NSDate *end = [NSDate dateWithTimeIntervalSince1970:60 * 60 * 13]; // 13:00 GMT

    [[UAPush shared] setQuietTimeFrom:start
                                   to:end
                         withTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"]];

    XCTAssertEqualObjects(@"GMT", [[UAPush shared].timeZone abbreviation],
                          @"Timezone should be set to the timezone in quiet time");

    NSDictionary *quietTime = [UAPush shared].quietTime;
    XCTAssertEqualObjects(@"0:01", [quietTime valueForKey:UAPushQuietTimeStartKey],
                          @"Quiet time start is not set correctly");
    XCTAssertEqualObjects(@"13:00", [quietTime valueForKey:UAPushQuietTimeEndKey],
                          @"Quiet time end is not set correctly");


    // Test setting timezone to -5 GMT
    [[UAPush shared] setQuietTimeFrom:start
                                   to:end
                         withTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:-3600*5]];

    quietTime = [UAPush shared].quietTime;
    XCTAssertEqualObjects(@"19:01", [quietTime valueForKey:UAPushQuietTimeStartKey],
                          @"Quiet time start is not set handling timezone to -5 GMT correctly");

    XCTAssertEqualObjects(@"8:00", [quietTime valueForKey:UAPushQuietTimeEndKey],
                          @"Quiet time end is not set handling timezone to -5 GMT correctly");
}

- (void)testSetQuietTimeDeprecatedNoTimeZone {
    NSDate *start = [NSDate dateWithTimeIntervalSince1970:60]; // 0:01 GMT
    NSDate *end = [NSDate dateWithTimeIntervalSince1970:60 * 60 * 13]; // 13:00 GMT

    // Set the current timezone to CDT
    [UAPush shared].timeZone = [NSTimeZone timeZoneWithAbbreviation:@"CDT"];

    // When timezone is nil, it uses whatever defaultQuietTimeZone is, then sets it to timezone
    [[UAPush shared] setQuietTimeFrom:start to:end withTimeZone:nil];

    XCTAssertEqualObjects([[UAPush shared].defaultTimeZoneForQuietTime abbreviation],
                          [[UAPush shared].timeZone abbreviation],
                          @"Timezone should be set to defaultTimeZoneForQuietTime");
}

- (void)testTimeZone {
    [UAPush shared].timeZone = [NSTimeZone timeZoneWithAbbreviation:@"EST"];

    XCTAssertEqualObjects([NSTimeZone timeZoneWithAbbreviation:@"EST"],
                          [UAPush shared].timeZone,
                          @"timezone is not being set correctly");

    XCTAssertEqualObjects([[NSTimeZone timeZoneWithAbbreviation:@"EST"] name],
                          [[NSUserDefaults standardUserDefaults] stringForKey:UAPushTimeZoneSettingsKey],
                          @"timezone should be stored in standardUserDefaults");

    [UAPush shared].timeZone = nil;

    XCTAssertEqualObjects([[UAPush shared].defaultTimeZoneForQuietTime abbreviation],
                          [[UAPush shared].timeZone abbreviation],
                          @"Timezone should default to defaultTimeZoneForQuietTime");

    XCTAssertNil([[NSUserDefaults standardUserDefaults] stringForKey:UAPushTimeZoneSettingsKey],
                 @"timezone should be able to be cleared in standardUserDefaults");
}

- (void)testRegisterForRemoteNotificationsPushEnabled {
    [UAPush shared].pushEnabled = YES;
    [UAPush shared].notificationTypes = UIRemoteNotificationTypeSound;

    [[self.mockedApplication expect] registerForRemoteNotificationTypes:UIRemoteNotificationTypeSound];
    [[UAPush shared] registerForRemoteNotifications];

    XCTAssertNoThrow([self.mockedApplication verify],
                     @"should register for push notification types when push is enabled");

}

- (void)testRegisterForRemoteNotificationsPushDisabled {
    [UAPush shared].pushEnabled = NO;
    [UAPush shared].notificationTypes = UIRemoteNotificationTypeSound;

    [[self.mockedApplication reject] registerForRemoteNotificationTypes:UIRemoteNotificationTypeSound];
    [[UAPush shared] registerForRemoteNotifications];

    XCTAssertNoThrow([self.mockedApplication verify],
                     @"should not register for push notification types when push is disabled");
}

- (void)testRegisterForRemoteNotificationTypesPushEnabled {
    [UAPush shared].pushEnabled = YES;
    [UAPush shared].notificationTypes = UIRemoteNotificationTypeSound;

    [[self.mockedApplication expect] registerForRemoteNotificationTypes:UIRemoteNotificationTypeBadge];
    [[UAPush shared] registerForRemoteNotificationTypes:UIRemoteNotificationTypeBadge];

    XCTAssertNoThrow([self.mockedApplication verify],
                     @"should register for push notification types when push is enabled");

    XCTAssertEqual(UIRemoteNotificationTypeBadge, [UAPush shared].notificationTypes,
                   @"registerForPushNotificationTypes should still set the notificationTypes when push is enabled");
}

- (void)testRegisterForRemoteNotificationTypesPushDisabled {
    [UAPush shared].notificationTypes = UIRemoteNotificationTypeSound;
    [UAPush shared].pushEnabled = NO;

    [[self.mockedApplication reject] registerForRemoteNotificationTypes:UIRemoteNotificationTypeBadge];
    [[UAPush shared] registerForRemoteNotificationTypes:UIRemoteNotificationTypeBadge];

    XCTAssertNoThrow([self.mockedApplication verify],
                     @"should not register for push notification types when push is disabled");

    XCTAssertEqual(UIRemoteNotificationTypeBadge, [UAPush shared].notificationTypes,
                   @"registerForPushNotificationTypes should still set the notificationTypes when push is disabled");
}

- (void)testSetBadgeNumberAutoBadgeEnabled{
    // Set the right values so we can check if a device api client call was made or not
    [UAPush shared].pushEnabled = YES;
    [UAPush shared].autobadgeEnabled = YES;
    [UAPush shared].deviceToken = validDeviceToken;

    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE((NSInteger)30)] applicationIconBadgeNumber];

    [[self.mockedApplication expect] setApplicationIconBadgeNumber:15];
    [[self.mockedDeviceRegistrar expect] registerWithChannelID:OCMOCK_ANY
                                               channelLocation:OCMOCK_ANY
                                                   withPayload:OCMOCK_ANY
                                                    forcefully:YES];

    [[UAPush shared] setBadgeNumber:15];
    XCTAssertNoThrow([self.mockedApplication verify],
                     @"should update application icon badge number when its different");

    XCTAssertNoThrow([self.mockedDeviceRegistrar verify],
                     @"should update registration so autobadge works");
}

- (void)testSetBadgeNumberNoChange {
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE((NSInteger)30)] applicationIconBadgeNumber];
    [[self.mockedApplication reject] setApplicationIconBadgeNumber:30];

    [[UAPush shared] setBadgeNumber:30];
    XCTAssertNoThrow([self.mockedApplication verify],
                     @"should not update application icon badge number if there is no change");
}

- (void)testSetBadgeNumberAutoBadgeDisabled {
    [UAPush shared].pushEnabled = YES;
    [UAPush shared].deviceToken = validDeviceToken;

    [UAPush shared].autobadgeEnabled = NO;

    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE((NSInteger)30)] applicationIconBadgeNumber];
    [[self.mockedApplication expect] setApplicationIconBadgeNumber:15];

    // Reject device api client registration because autobadge is not enabled
    [[self.mockedDeviceRegistrar reject] registerWithChannelID:OCMOCK_ANY
                                               channelLocation:OCMOCK_ANY
                                                   withPayload:OCMOCK_ANY
                                                    forcefully:YES];
    [[UAPush shared] setBadgeNumber:15];
    XCTAssertNoThrow([self.mockedApplication verify],
                     @"should update application icon badge number when its different");

    XCTAssertNoThrow([self.mockedDeviceRegistrar verify],
                     @"should not update registration because autobadge is disabled");
}

- (void)testRegisterDeviceToken {
    [UAPush shared].notificationTypes = UIRemoteNotificationTypeSound;
    [UAPush shared].pushEnabled = YES;
    [UAPush shared].deviceToken = nil;

    NSData *token = [@"some-token" dataUsingEncoding:NSASCIIStringEncoding];
    [[self.mockedAnalytics expect] addEvent:OCMOCK_ANY];

    [[self.mockedDeviceRegistrar expect] registerWithChannelID:OCMOCK_ANY
                                               channelLocation:OCMOCK_ANY
                                                   withPayload:OCMOCK_ANY
                                                    forcefully:NO];

    [[UAPush shared] registerDeviceToken:token];

    XCTAssertNoThrow([self.mockedAnalytics verify],
                     @"should add device registration event to analytics");

    XCTAssertNoThrow([self.mockedDeviceRegistrar verify],
                     @"should update registration on registering device token");

    // 736f6d652d746f6b656e = "some-token" in hex
    XCTAssertEqualObjects(@"736f6d652d746f6b656e", [UAPush shared].deviceToken, @"Register device token should set the device token");
}

/**
 * Test registering a device token in the background does not
 * update registration if we already have a channel
 */
- (void)testRegisterDeviceTokenBackground {
    [UAPush shared].notificationTypes = UIRemoteNotificationTypeSound;
    [UAPush shared].pushEnabled = YES;
    [UAPush shared].deviceToken = nil;
    [UAPush shared].channelID = @"channel";

    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateBackground)] applicationState];


    NSData *token = [@"some-token" dataUsingEncoding:NSASCIIStringEncoding];
    [[self.mockedAnalytics expect] addEvent:OCMOCK_ANY];

    [[self.mockedDeviceRegistrar reject] registerWithChannelID:OCMOCK_ANY
                                               channelLocation:OCMOCK_ANY
                                                   withPayload:OCMOCK_ANY
                                                    forcefully:NO];

    [[UAPush shared] registerDeviceToken:token];

    XCTAssertNoThrow([self.mockedAnalytics verify],
                     @"should add device registration event to analytics");

    XCTAssertNoThrow([self.mockedDeviceRegistrar verify],
                     @"should not allow registration in background except for channel creation");

    // 736f6d652d746f6b656e = "some-token" in hex
    XCTAssertEqualObjects(@"736f6d652d746f6b656e", [UAPush shared].deviceToken, @"Register device token should set the device token");
}

/**
 * Test registering a device token in the background does not
 * update registration if we are using device registration
 */
- (void)testRegisterDeviceTokenBackgroundDeviceRegistration {
    [UAPush shared].notificationTypes = UIRemoteNotificationTypeSound;
    [UAPush shared].pushEnabled = YES;
    [UAPush shared].deviceToken = nil;

    [[[self.mockedDeviceRegistrar stub] andReturnValue:OCMOCK_VALUE(NO)] isUsingChannelRegistration];
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateBackground)] applicationState];


    NSData *token = [@"some-token" dataUsingEncoding:NSASCIIStringEncoding];
    [[self.mockedAnalytics expect] addEvent:OCMOCK_ANY];

    [[self.mockedDeviceRegistrar reject] registerWithChannelID:OCMOCK_ANY
                                               channelLocation:OCMOCK_ANY
                                                   withPayload:OCMOCK_ANY
                                                    forcefully:NO];

    [[UAPush shared] registerDeviceToken:token];

    XCTAssertNoThrow([self.mockedAnalytics verify],
                     @"should add device registration event to analytics");

    XCTAssertNoThrow([self.mockedDeviceRegistrar verify],
                     @"should not allow registration in background except for channel creation");

    // 736f6d652d746f6b656e = "some-token" in hex
    XCTAssertEqualObjects(@"736f6d652d746f6b656e", [UAPush shared].deviceToken, @"Register device token should set the device token");
}

/**
 * Test device token registration in the background updates registration for
 * channel creation.
 */
- (void)testRegisterDeviceTokenBackgroundChannelCreation {
    [UAPush shared].notificationTypes = UIRemoteNotificationTypeSound;
    [UAPush shared].pushEnabled = YES;
    [UAPush shared].deviceToken = nil;
    [UAPush shared].channelID = nil;

    [[[self.mockedDeviceRegistrar stub] andReturnValue:OCMOCK_VALUE(YES)] isUsingChannelRegistration];
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateBackground)] applicationState];


    NSData *token = [@"some-token" dataUsingEncoding:NSASCIIStringEncoding];
    [[self.mockedAnalytics expect] addEvent:OCMOCK_ANY];

    [[self.mockedDeviceRegistrar expect] registerWithChannelID:OCMOCK_ANY
                                               channelLocation:OCMOCK_ANY
                                                   withPayload:OCMOCK_ANY
                                                    forcefully:NO];

    [[UAPush shared] registerDeviceToken:token];

    XCTAssertNoThrow([self.mockedAnalytics verify],
                     @"should add device registration event to analytics");

    XCTAssertNoThrow([self.mockedDeviceRegistrar verify],
                     @"should update registration on registering device token");

    // 736f6d652d746f6b656e = "some-token" in hex
    XCTAssertEqualObjects(@"736f6d652d746f6b656e", [UAPush shared].deviceToken, @"Register device token should set the device token");
}

- (void)testRegisterDeviceTokenNoNotificationTypes {
    [UAPush shared].notificationTypes = 0;
    [UAPush shared].pushEnabled = YES;
    [UAPush shared].deviceToken = nil;

    NSData *token = [@"some-token" dataUsingEncoding:NSASCIIStringEncoding];
    [[self.mockedAnalytics reject] addEvent:OCMOCK_ANY];
    [[self.mockedDeviceRegistrar reject] registerWithChannelID:OCMOCK_ANY
                                               channelLocation:OCMOCK_ANY
                                                   withPayload:OCMOCK_ANY
                                                    forcefully:NO];
    [[UAPush shared] registerDeviceToken:token];

    XCTAssertNoThrow([self.mockedAnalytics verify],
                     @"should not do anything if notificationTypes are not set");

    XCTAssertNoThrow([self.mockedDeviceRegistrar verify],
                     @"should not do anything if notificationTypes are not set");
}

- (void)testRegisterNSUserDefaultsSetsPushEnabled {
    // Clear out any existing push enabled defaults values
    NSMutableDictionary *defaults = [NSMutableDictionary dictionaryWithCapacity:2];
    [defaults setValue:[NSNumber numberWithBool:NO] forKey:UAPushEnabledSettingsKey];
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];

    // Remove existing push setting
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:UAPushEnabledSettingsKey];

     XCTAssertFalse([[NSUserDefaults standardUserDefaults] boolForKey:UAPushEnabledSettingsKey],
                    @"Unable to set push enable default");

    [UAPush registerNSUserDefaults];

    XCTAssertTrue([[NSUserDefaults standardUserDefaults] boolForKey:UAPushEnabledSettingsKey],
                  @"register defaults should set default value of pushEnabled to YES");
}

- (void)testRegisterNSUserDefaultsQuietTime {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:UAPushQuietTimeEnabledSettingsKey];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:UAPushQuietTimeSettingsKey];

    [UAPush registerNSUserDefaults];
    XCTAssertFalse([[NSUserDefaults standardUserDefaults] boolForKey:UAPushQuietTimeEnabledSettingsKey],
                   @"Quiet time should not be enabled if neither setting or enabled is set");

    // Add quiet time dictionary and remove the enable setting
    [[NSUserDefaults standardUserDefaults] setValue:[NSDictionary dictionary] forKey:UAPushQuietTimeSettingsKey];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:UAPushQuietTimeEnabledSettingsKey];

    [UAPush registerNSUserDefaults];
    XCTAssertTrue([[NSUserDefaults standardUserDefaults] boolForKey:UAPushQuietTimeEnabledSettingsKey],
                  @"Quiet time should be enabled if quiet time setting has a value but enabled does not");

    // Set quiet time enabled to false to make sure it does not get set back to true
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:UAPushQuietTimeEnabledSettingsKey];

    [UAPush registerNSUserDefaults];
    XCTAssertFalse([[NSUserDefaults standardUserDefaults] boolForKey:UAPushQuietTimeEnabledSettingsKey],
                   @"Quiet time should not be enabled if it already is set to disable");
}

- (void)testSetDefaultPushEnabledValue {
    [UAPush setDefaultPushEnabledValue:YES];

    [[NSUserDefaults standardUserDefaults] removeObjectForKey:UAPushEnabledSettingsKey];
    XCTAssertTrue([[NSUserDefaults standardUserDefaults] boolForKey:UAPushEnabledSettingsKey],
                  @"UAPushEnabledSettingsKey in standardUserDefaults should default to YES");

    [UAPush setDefaultPushEnabledValue:NO];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:UAPushEnabledSettingsKey];
    XCTAssertFalse([[NSUserDefaults standardUserDefaults] boolForKey:UAPushEnabledSettingsKey],
                   @"UAPushEnabledSettingsKey in standardUserDefaults should default to NO");
}


- (void)testUpdateRegistrationForcefullyPushEnabled {
    [UAPush shared].pushEnabled = YES;
    [UAPush shared].deviceToken = validDeviceToken;

    // Check every app state.  We want to allow manual registration in any state.
    for(int i = UIApplicationStateActive; i < UIApplicationStateBackground; i++) {
        UIApplicationState state = (UIApplicationState)i;
        [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(state)] applicationState];

        [[self.mockedDeviceRegistrar expect] registerWithChannelID:OCMOCK_ANY
                                                   channelLocation:OCMOCK_ANY
                                                       withPayload:OCMOCK_ANY
                                                        forcefully:YES];

        [[UAPush shared] updateRegistrationForcefully:YES];
        XCTAssertNoThrow([self.mockedDeviceRegistrar verify],
                         @"updateRegistration should register with the device registrar if push is enabled.");
    }
}


- (void)testUpdateRegistrationForcefullyPushDisabled {
    [UAPush shared].pushEnabled = NO;
    [UAPush shared].deviceToken = validDeviceToken;

    [[self.mockedDeviceRegistrar expect] registerPushDisabledWithChannelID:OCMOCK_ANY
                                                           channelLocation:OCMOCK_ANY
                                                               withPayload:OCMOCK_ANY
                                                                forcefully:YES];

    [[UAPush shared] updateRegistrationForcefully:YES];
    XCTAssertNoThrow([self.mockedDeviceRegistrar verify],
                     @"updateRegistration should unregister with the device registrar if push is disabled.");
}

- (void)testRegistrationPayload {
    // Set up UAPush to give a full, opted in payload
    [UAPush shared].deviceToken = validDeviceToken;
    [UAPush shared].alias = @"ALIAS";
    [UAPush shared].deviceTagsEnabled = YES;
    [UAPush shared].tags = @[@"tag-one"];
    [UAPush shared].autobadgeEnabled = NO;
    [UAPush shared].quietTimeEnabled = YES;
    [[UAPush shared] setQuietTimeFrom:[NSDate dateWithTimeIntervalSince1970:0]
                                   to:[NSDate dateWithTimeIntervalSince1970:10]
                         withTimeZone:[NSTimeZone timeZoneWithName:@"Pacific/Auckland"]];

    // Opt in requirements
    [UAPush shared].pushEnabled = YES;
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIRemoteNotificationTypeAlert)] enabledRemoteNotificationTypes];

    UAChannelRegistrationPayload *expectedPayload = [[UAChannelRegistrationPayload alloc] init];
    expectedPayload.deviceID = @"someDeviceID";
    expectedPayload.userID = @"someUser";
    expectedPayload.pushAddress = validDeviceToken;
    expectedPayload.optedIn = true;
    expectedPayload.tags = @[@"tag-one"];
    expectedPayload.setTags = YES;
    expectedPayload.alias = @"ALIAS";
    expectedPayload.badge = nil;
    expectedPayload.quietTime = @{@"end":@"12:00", @"start":@"12:00"};
    expectedPayload.timeZone = @"Pacific/Auckland";

    BOOL (^checkPayloadBlock)(id obj) = ^(id obj) {
        UAChannelRegistrationPayload *payload = obj;
        return [payload isEqualToPayload:expectedPayload];
    };

    [[self.mockedDeviceRegistrar expect] registerWithChannelID:OCMOCK_ANY
                                               channelLocation:OCMOCK_ANY
                                                   withPayload:[OCMArg checkWithBlock:checkPayloadBlock]
                                                    forcefully:YES];

    [[UAPush shared] updateRegistrationForcefully:YES];

    XCTAssertNoThrow([self.mockedDeviceRegistrar verify],
                     @"payload is not being created with expected values");
}

- (void)testRegistrationPayloadNoDeviceToken {
    // Set up UAPush to give minimum payload
    [UAPush shared].deviceToken = nil;
    [UAPush shared].alias = nil;
    [UAPush shared].deviceTagsEnabled = NO;
    [UAPush shared].autobadgeEnabled = NO;
    [UAPush shared].quietTimeEnabled = NO;

    // Opt in requirements
    [UAPush shared].pushEnabled = YES;
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIRemoteNotificationTypeAlert)] enabledRemoteNotificationTypes];

    // Verify opt in is false when device token is nil
    UAChannelRegistrationPayload *expectedPayload = [[UAChannelRegistrationPayload alloc] init];
    expectedPayload.deviceID = @"someDeviceID";
    expectedPayload.userID = @"someUser";
    expectedPayload.optedIn = false;
    expectedPayload.setTags = NO;

    BOOL (^checkPayloadBlock)(id obj) = ^(id obj) {
        UAChannelRegistrationPayload *payload = obj;
        return [payload isEqualToPayload:expectedPayload];
    };

    [[self.mockedDeviceRegistrar expect] registerWithChannelID:OCMOCK_ANY channelLocation:OCMOCK_ANY withPayload:[OCMArg checkWithBlock:checkPayloadBlock] forcefully:YES];

    [[UAPush shared] updateRegistrationForcefully:YES];

    XCTAssertNoThrow([self.mockedDeviceRegistrar verify],
                     @"payload is not being created with expected values");

}

- (void)testRegistrationPayloadDeviceTagsDisabled {
    [UAPush shared].pushEnabled = YES;
    [UAPush shared].deviceTagsEnabled = NO;
    [UAPush shared].tags = @[@"tag-one"];

    // Check that the payload setTags is NO and the tags is nil
    BOOL (^checkPayloadBlock)(id obj) = ^(id obj) {
        UAChannelRegistrationPayload *payload = obj;
        return (BOOL)(!payload.setTags && payload.tags == nil);
    };

    [[self.mockedDeviceRegistrar expect] registerWithChannelID:OCMOCK_ANY
                                               channelLocation:OCMOCK_ANY
                                                   withPayload:[OCMArg checkWithBlock:checkPayloadBlock]
                                                    forcefully:YES];

    [[UAPush shared] updateRegistrationForcefully:YES];

    XCTAssertNoThrow([self.mockedDeviceRegistrar verify],
                     @"payload is including tags when device tags is NO");

}

- (void)testRegistrationPayloadAutoBadgeEnabled {
    [UAPush shared].pushEnabled = YES;
    [UAPush shared].autobadgeEnabled = YES;
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE((NSInteger)30)] applicationIconBadgeNumber];

    // Check that the payload setTags is NO and the tags is nil
    BOOL (^checkPayloadBlock)(id obj) = ^(id obj) {
        UAChannelRegistrationPayload *payload = obj;
        return (BOOL)([payload.badge integerValue] == 30);
    };

    [[self.mockedDeviceRegistrar expect] registerWithChannelID:OCMOCK_ANY
                                               channelLocation:OCMOCK_ANY
                                                   withPayload:[OCMArg checkWithBlock:checkPayloadBlock]
                                                    forcefully:YES];

    [[UAPush shared] updateRegistrationForcefully:YES];

    XCTAssertNoThrow([self.mockedDeviceRegistrar verify],
                     @"payload is not including the correct badge when auto badge is enabled");
}

- (void)testRegistrationPayloadNoQuietTime {
    [UAPush shared].pushEnabled = YES;
    [UAPush shared].quietTimeEnabled = NO;
    [[UAPush shared] setQuietTimeFrom:[NSDate dateWithTimeIntervalSince1970:0]
                                   to:[NSDate dateWithTimeIntervalSince1970:10]
                         withTimeZone:[NSTimeZone timeZoneWithName:@"Pacific/Auckland"]];


    // Check that the payload does not include a quiet time
    BOOL (^checkPayloadBlock)(id obj) = ^(id obj) {
        UAChannelRegistrationPayload *payload = obj;
        return (BOOL)(payload.quietTime == nil);
    };

    [[self.mockedDeviceRegistrar expect] registerWithChannelID:OCMOCK_ANY
                                               channelLocation:OCMOCK_ANY
                                                   withPayload:[OCMArg checkWithBlock:checkPayloadBlock]
                                                    forcefully:YES];

    [[UAPush shared] updateRegistrationForcefully:YES];

    XCTAssertNoThrow([self.mockedDeviceRegistrar verify],
                     @"payload should not include quiet time if quiet time is disabled");
}


/**
 * Test handleNotification: and handleNotification:fetchCompletionHandler:
 * call the action runner with the correct arguments and report correctly to
 * analytics
 */
- (void)testHandleNotification {
    __block UASituation expectedSituation;
    __block UAActionFetchResult fetchResult = UAActionFetchResultNoData;

    BOOL (^runActionsCheck)(id obj) = ^(id obj) {
        NSDictionary *actions = (NSDictionary *)obj;
        if (actions.count < 1) {
            return NO;
        }

        // Validate incoming push action is added
        UAActionArguments *args = [actions valueForKey:kUAIncomingPushActionRegistryName];
        if (!args || args.situation != expectedSituation) {
            return NO;
        }

        // Validate other push action is added
        args = [actions valueForKey:@"someActionKey"];
        if (!args || (args.situation != expectedSituation || ![args.value isEqualToString:@"someActionValue"])) {
            return NO;
        }



        return YES;
    };

    BOOL (^handlerCheck)(id obj) = ^(id obj) {
        void (^handler)(UAActionResult *) = obj;
        if (handler) {
            handler([UAActionResult resultWithValue:nil withFetchResult:fetchResult]);
        }
        return YES;
    };

    // Create arrays of the expected results
    UAActionFetchResult fetchResults[] = {UAActionFetchResultFailed, UAActionFetchResultNewData, UAActionFetchResultNoData};
    UIApplicationState applicationStates[] = {UIApplicationStateBackground, UIApplicationStateInactive, UIApplicationStateActive};
    UASituation situations[] = {UASituationBackgroundPush, UASituationLaunchedFromPush, UASituationForegroundPush};

    for(NSInteger stateIndex = 0; stateIndex < 3; stateIndex++) {
        expectedSituation = situations[stateIndex];
        UIApplicationState applicationState = applicationStates[stateIndex];

        // Test handleNotification: first
        [[self.mockActionRunner expect] runActions:[OCMArg checkWithBlock:runActionsCheck] withCompletionHandler:[OCMArg checkWithBlock:handlerCheck]];
        [[self.mockedAnalytics expect] handleNotification:notification inApplicationState:applicationState];
        [[UAPush shared] handleNotification:notification applicationState:applicationState];

        XCTAssertNoThrow([self.mockActionRunner verify], @"handleNotification should run push actions with situation %ld", expectedSituation);
        XCTAssertNoThrow([self.mockedAnalytics verify], @"analytics should be notified of the incoming notification");

        // Test handleNotification:fetchCompletionHandler: for every background fetch result
        for (int fetchResultIndex = 0; fetchResultIndex < 3; fetchResultIndex++) {
            __block BOOL completionHandlerCalled = NO;
            fetchResult = fetchResults[fetchResultIndex];

            [[self.mockActionRunner expect] runActions:[OCMArg checkWithBlock:runActionsCheck] withCompletionHandler:[OCMArg checkWithBlock:handlerCheck]];
            [[self.mockedAnalytics expect] handleNotification:notification inApplicationState:applicationState];
            [[UAPush shared] handleNotification:notification applicationState:applicationState fetchCompletionHandler:^(UIBackgroundFetchResult result) {
                completionHandlerCalled = YES;

                // Relies on the fact that UAActionFetchResults cast correctly to UIBackgroundFetchResults
                XCTAssertEqual((NSUInteger)fetchResult, (NSUInteger)result, @"Unexpected fetch result");
            }];

            XCTAssertTrue(completionHandlerCalled, @"handleNotification should call fetch completion handler");
            XCTAssertNoThrow([self.mockActionRunner verify], @"handleNotification should run push actions with situation %ld", expectedSituation);
            XCTAssertNoThrow([self.mockedAnalytics verify], @"analytics should be notified of the incoming notification");
        }
    }

    // UIApplicationStateActive, no completion handler
    expectedSituation = UASituationForegroundPush;
    [[self.mockActionRunner expect] runActions:[OCMArg checkWithBlock:runActionsCheck] withCompletionHandler:[OCMArg checkWithBlock:handlerCheck]];
}

/**
 * Test handleNotification when auto badge is disabled does 
 * not set the badge on the application
 */
- (void)testHandleNotificationAutoBadgeDisabled {
    UAPush.shared.autobadgeEnabled = NO;
    [[self.mockedApplication reject] setApplicationIconBadgeNumber:2];
    [[UAPush shared] handleNotification:notification applicationState:UIApplicationStateActive];
    [[UAPush shared] handleNotification:notification applicationState:UIApplicationStateBackground];
    [[UAPush shared] handleNotification:notification applicationState:UIApplicationStateInactive];

    XCTAssertNoThrow([self.mockedApplication verify], @"Badge should only be updated if autobadge is enabled");
}

/**
 * Test handleNotification when auto badge is enabled sets the badge
 * only when a notification comes in while the app is in the foreground
 */
- (void)testHandleNotificationAutoBadgeEnabled {
    UAPush.shared.autobadgeEnabled = YES;

    [[self.mockedApplication expect] setApplicationIconBadgeNumber:2];
    [[UAPush shared] handleNotification:notification applicationState:UIApplicationStateActive];

    XCTAssertNoThrow([self.mockedApplication verify], @"Badge should be updated if app is in the foreground");

    [[self.mockedApplication reject] setApplicationIconBadgeNumber:2];
    [[UAPush shared] handleNotification:notification applicationState:UIApplicationStateBackground];
    [[UAPush shared] handleNotification:notification applicationState:UIApplicationStateInactive];

    XCTAssertNoThrow([self.mockedApplication verify], @"Badge should only be updated if app is in the foreground");
}

/**
 * Test handleNotification in an inactive state sets the launchNotification  
 */
- (void)testHandleNotificationLaunchNotification {
    [UAPush shared].launchNotification = nil;
    [[UAPush shared] handleNotification:notification applicationState:UIApplicationStateActive];
    [[UAPush shared] handleNotification:notification applicationState:UIApplicationStateBackground];

    XCTAssertNil([UAPush shared].launchNotification, @"Launch notification should only be set in an inactive state");

    [[UAPush shared] handleNotification:notification applicationState:UIApplicationStateInactive];
    XCTAssertNotNil([UAPush shared].launchNotification, @"Launch notification should be set in an inactive state");
}

/**
 * Test applicationDidEnterBackground clears the notification and sets 
 * the hasEnteredBackground flag
 */
- (void)testApplicationDidEnterBackground {
    UAPush *push = [UAPush shared];
    push.hasEnteredBackground = NO;
    push.launchNotification = notification;

    [push applicationDidEnterBackground];
    XCTAssertTrue(push.hasEnteredBackground, @"applicationDidEnterBackground should set hasEnteredBackground to true");
    XCTAssertNil(push.launchNotification, @"applicationDidEnterBackground should clear the launch notification");
    XCTAssertTrue([[NSUserDefaults standardUserDefaults] boolForKey:UAPushChannelCreationOnForeground], @"applicationDidEnterBackground should set channelCreationOnForeground to true");
}

/**
 * Test springboard actions are called if application did enter foreground when 
 * the launch notification is nil
 */
- (void)testApplicationDidBecomeActiveSpringBoardActions {
    UAPush *push = [UAPush shared];
    push.launchNotification = nil;

    [UAActionArguments clearSpringBoardActionArguments];
    [UAActionArguments addPendingSpringBoardAction:@"some-action" value:@"some-value"];
    [UAActionArguments addPendingSpringBoardAction:@"some-other-action" value:@"some-other-value"];

    BOOL (^runActionsCheck)(id obj) = ^(id obj) {
        NSDictionary *actions = (NSDictionary *)obj;
        if (actions.count != 2) {
            return NO;
        }

        UAActionArguments *args = [actions valueForKey:@"some-action"];
        return (BOOL)(args != nil
                      && args.situation == UASituationLaunchedFromSpringBoard
                      && [args.value isEqualToString:@"some-value"]);
    };


    [[self.mockActionRunner expect] runActions:[OCMArg checkWithBlock:runActionsCheck] withCompletionHandler:OCMOCK_ANY];

    [push applicationDidBecomeActive];
    XCTAssertNoThrow([self.mockActionRunner verify], @"springboard launch should run springboard actions");
    XCTAssertEqual((NSUInteger)0, [UAActionArguments pendingSpringBoardPushActionArguments].count, @"springboard actions should be cleared");


    push.launchNotification = notification;
    [[self.mockActionRunner reject] runActions:OCMOCK_ANY withCompletionHandler:OCMOCK_ANY];
    [push applicationDidBecomeActive];
    XCTAssertNoThrow([self.mockActionRunner verify], @"springboard actions should not be ran if a launchNotification is available");
}

/**
 * Test the registrationFinished finishes the backgroundTask if the background
 * task is valid
 */
- (void)testRegistrationFinishedInBackground {
    UAPush *push = [UAPush shared];

    // Give push a valid background task identifier
    push.registrationBackgroundTask = 100;

    [[self.mockedApplication expect] endBackgroundTask:100];

    [push registrationFinished:[NSNotification notificationWithName:@"someName" object:nil]];
    XCTAssertNoThrow([self.mockedApplication verify], @"The registrationFinished in the background task should be valid.");
    XCTAssertEqual(UIBackgroundTaskInvalid, push.registrationBackgroundTask, @"Background task identifier should be set back to invalid.");
}

/**
 * Test that a background task is created when entering the background and
 * registration is in progress
 */
- (void)testBackgroundTaskCreatedWhenRegistrationInProgress {
    UAPush *push = [UAPush shared];
    push.channelID = @"some-channel";
    [[[self.mockedDeviceRegistrar stub] andReturnValue:OCMOCK_VALUE(YES)] isRegistrationInProgress];

    [[[self.mockedApplication expect] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    [push applicationDidEnterBackground];

    XCTAssertNoThrow([self.mockedApplication verify], @"A background task should be created when a registration is in progress");
    XCTAssertEqual((NSUInteger)30, push.registrationBackgroundTask, @"registrationBackgroundTask should be set to the background task ID");
}

/**
 * Test that a background task is created when entering the background and
 * a channel id needs to be created.
 */
- (void)testBackgroundTaskCreatedNeedChannelID {
    UAPush *push = [UAPush shared];
    push.channelID = nil;
    [[[self.mockedDeviceRegistrar stub] andReturnValue:OCMOCK_VALUE(NO)] isRegistrationInProgress];
    [[[self.mockedDeviceRegistrar stub] andReturnValue:OCMOCK_VALUE(YES)] isUsingChannelRegistration];

    [[[self.mockedApplication expect] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    [push applicationDidEnterBackground];

    XCTAssertNoThrow([self.mockedApplication verify], @"A background task should be created when a registration is in progress");
    XCTAssertEqual((NSUInteger)30, push.registrationBackgroundTask, @"registrationBackgroundTask should be set to the background task ID");
}

/**
 * Test that a background task is not created when entering the background 
 * if we dont need a channel id or registrations are not in progress
 */
- (void)testBackgroundTaskNotCreated {
    UAPush *push = [UAPush shared];
    push.channelID = @"some-channel";
    [[[self.mockedDeviceRegistrar stub] andReturnValue:OCMOCK_VALUE(NO)] isRegistrationInProgress];

    [[[self.mockedApplication reject] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    [push applicationDidEnterBackground];

    XCTAssertNoThrow([self.mockedApplication verify], @"A background task should be created when a registration is in progress");
}

/**
 * Test channel created
 */
- (void)testChannelCreated {
    UAPush *push = [UAPush shared];

    NSNotification *notification = [NSNotification notificationWithName:UAChannelCreatedNotification
                                                                 object:nil
                                                               userInfo:@{UAChannelNotificationKey: @"someChannelID",
                                                                          UAChannelLocationNotificationKey:@"someLocation"}];

    [push channelCreated:notification];
    XCTAssertEqualObjects(push.channelID, @"someChannelID", @"The channel ID should be set on channel creation.");
    XCTAssertEqualObjects(push.channelLocation, @"someLocation", @"The channel location should be set on channel creation.");

}

/**
 * Test channel conflict
 */
- (void)testChannelConflict {
    UAPush *push = [UAPush shared];

    NSDictionary *userInfo = @{
                               UAChannelNotificationKey: @"someNewChannel",
                               UAChannelLocationNotificationKey: @"someNewChannelLocation",
                               UAReplacedChannelNotificationKey: @"someOldChannel",
                               UAReplacedChannelLocationNotificationKey: @"someOldLocation"
                               };

    NSNotification *notification = [NSNotification notificationWithName:UAChannelConflictNotification
                                                                 object:nil
                                                               userInfo:userInfo];


    [push channelConflict:notification];
    XCTAssertEqualObjects(push.channelID, @"someNewChannel", @"The channel should update to the new channel ID.");
    XCTAssertEqualObjects(push.channelLocation, @"someNewChannelLocation", @"The channel should update to the new channel location.");

}

/**
 * Test setting the channel ID generates the device registration event with the
 * channel ID.
 */
- (void)testSetChannelID {
    UAPush *push = [UAPush shared];

    push.channelID = @"someChannelID";

    XCTAssertEqualObjects(@"someChannelID", push.channelID, @"Channel ID is not being set properly");
}

@end
