/*
 Copyright 2009-2014 Urban Airship Inc. All rights reserved.

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
#import "UAActionRegistry+Internal.h"
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
@property(nonatomic, strong) UAPush *push;
@property(nonatomic, strong) NSDictionary *notification;

@end

@implementation UAPushTest

NSString *validDeviceToken = @"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";


- (void)setUp {
    [super setUp];

    self.push = [[UAPush alloc] init];

    self.notification = @{ @"aps":
                          @{ @"alert": @"sample alert!", @"badge": @2, @"sound": @"cat" },
                      @"someActionKey": @"someActionValue"
                    };

    // Set up a mocked application
    self.mockedApplication = [OCMockObject niceMockForClass:[UIApplication class]];
    [[[self.mockedApplication stub] andReturn:self.mockedApplication] sharedApplication];

    // Set up a mocked device api client
    self.mockedDeviceRegistrar = [OCMockObject niceMockForClass:[UADeviceRegistrar class]];
    self.push.deviceRegistrar.delegate = nil;
    self.push.deviceRegistrar = self.mockedDeviceRegistrar;

    self.mockedAnalytics = [OCMockObject niceMockForClass:[UAAnalytics class]];

    self.mockedAirshipClass =[OCMockObject niceMockForClass:[UAirship class]];
    [[[self.mockedAirshipClass stub] andReturn:self.mockedAirshipClass] shared];
    [[[self.mockedAirshipClass stub] andReturn:self.mockedAnalytics] analytics];

    self.mockedPushDelegate = [OCMockObject niceMockForProtocol:@protocol(UAPushNotificationDelegate)];
    self.push.pushNotificationDelegate = self.mockedPushDelegate;

    self.mockRegistrationDelegate = [OCMockObject mockForProtocol:@protocol(UARegistrationDelegate)];

    self.mockActionRunner = [OCMockObject mockForClass:[UAActionRunner class]];

    self.mockUAUtils = [OCMockObject niceMockForClass:[UAUtils class]];
    [[[self.mockUAUtils stub] andReturn:@"someDeviceID"] deviceID];

    self.mockUAUser = [OCMockObject niceMockForClass:[UAUser class]];
    [[[self.mockUAUser stub] andReturn:self.mockUAUser] defaultUser];
    [[[self.mockUAUser stub] andReturn:@"someUser"] username];


    self.push.registrationDelegate = self.mockRegistrationDelegate;
}

- (void)tearDown {
    self.push.pushNotificationDelegate = nil;
    self.push.registrationDelegate = nil;

    [self.mockedApplication stopMocking];
    [self.mockedDeviceRegistrar stopMocking];
    [self.mockedAnalytics stopMocking];
    [self.mockedAirshipClass stopMocking];
    [self.mockedPushDelegate stopMocking];
    [self.mockRegistrationDelegate stopMocking];
    [self.mockActionRunner stopMocking];
    [self.mockUAUtils stopMocking];
    [self.mockUAUser stopMocking];

    [super tearDown];
}

- (void)testSetDeviceToken {

    self.push.deviceToken = nil;

    self.push.deviceToken = @"invalid characters";

    XCTAssertNil(self.push.deviceToken, @"setDeviceToken should ignore device tokens with invalid characters.");


    self.push.deviceToken = validDeviceToken;
    XCTAssertEqualObjects(validDeviceToken, self.push.deviceToken, @"setDeviceToken should set tokens with valid characters");

    self.push.deviceToken = nil;
    XCTAssertNil(self.push.deviceToken,
                          @"setDeviceToken should allow a nil device token.");

    self.push.deviceToken = @"";
    XCTAssertEqualObjects(@"", self.push.deviceToken,
                 @"setDeviceToken should do nothing to an empty string");
}

- (void)testAutoBadgeEnabled {
    self.push.autobadgeEnabled = true;
    XCTAssertTrue(self.push.autobadgeEnabled, @"autobadgeEnabled should be enabled when set to YES");
    XCTAssertTrue([[NSUserDefaults standardUserDefaults] boolForKey:UAPushBadgeSettingsKey],
                  @"autobadgeEnabled should be stored in standardUserDefaults");

    self.push.autobadgeEnabled = NO;
    XCTAssertFalse(self.push.autobadgeEnabled, @"autobadgeEnabled should be disabled when set to NO");
    XCTAssertFalse([[NSUserDefaults standardUserDefaults] boolForKey:UAPushBadgeSettingsKey],
                   @"autobadgeEnabled should be stored in standardUserDefaults");
}

- (void)testAlias {
    self.push.alias = @"some-alias";
    XCTAssertEqualObjects(@"some-alias", self.push.alias, @"alias is not being set correctly");
    XCTAssertEqualObjects(@"some-alias", [[NSUserDefaults standardUserDefaults] stringForKey:UAPushAliasSettingsKey],
                          @"alias should be stored in standardUserDefaults");

    self.push.alias = nil;
    XCTAssertNil(self.push.alias, @"alias should be able to be cleared");
    XCTAssertNil([[NSUserDefaults standardUserDefaults] stringForKey:UAPushAliasSettingsKey],
                 @"alias should be able to be cleared in standardUserDefaults");
}

- (void)testTags {
    NSArray *tags = @[@"tag-one", @"tag-two"];
    self.push.tags = tags;

    XCTAssertEqual((NSUInteger)2, self.push.tags.count, @"should of added 2 tags");
    XCTAssertEqualObjects(tags, self.push.tags, @"tags are not stored correctly");
    XCTAssertEqualObjects([[NSUserDefaults standardUserDefaults] valueForKey:UAPushTagsSettingsKey], self.push.tags,
                          @"tags are not stored correctly in standardUserDefaults");

    self.push.tags = nil;
    XCTAssertEqual((NSUInteger)0, self.push.tags.count, @"tags should return an empty array even when set to nil");
    XCTAssertEqual((NSUInteger)0, [[[NSUserDefaults standardUserDefaults] valueForKey:UAPushTagsSettingsKey] count],
                   @"tags are not being cleared in standardUserDefaults");
}

- (void)testSetTagsWhitespaceRemoval {
    NSArray *tags = @[@"   tag-one   ", @"tag-two   "];
    NSArray *tagsNoSpaces = @[@"tag-one", @"tag-two"];
    [self.push setTags:tags];
    
    XCTAssertEqualObjects(tagsNoSpaces, self.push.tags, @"whitespace was not trimmed from tags");
}

- (void)testSetTagsMaxTagSize {
    NSArray *tags = @[[@"" stringByPaddingToLength:127 withString: @"." startingAtIndex:0]];
    [self.push setTags:tags];
    
    XCTAssertEqualObjects(tags, self.push.tags, @"tag with 127 characters should set");
}

- (void)testSetTagWhitespaceOnly {
    NSArray *tags = @[@" "];
    [self.push setTags:tags];
    
    XCTAssertNotEqualObjects(tags, self.push.tags, @"tag with whitespace only should not set");
}

- (void)testSetTagsMinTagSize {
    NSArray *tags = @[@"1"];
    [self.push setTags:tags];
    
    XCTAssertEqualObjects(tags, self.push.tags, @"tag with 1 character should set");
}

- (void)testSetTagsMultiByteCharacters {
    NSArray *tags = @[@"함수 목록"];
    [self.push setTags:tags];
    
    XCTAssertEqualObjects(tags, self.push.tags, @"tag with multi-byte characters should set");
}

- (void)testSetTagsOverMaxTagSizeRemoval {
    NSArray *tags = @[[@"" stringByPaddingToLength:128 withString: @"." startingAtIndex:0]];
    [self.push setTags:tags];
    
    XCTAssertNotEqualObjects(tags, self.push.tags, @"tag with 128 characters should not set");
}

- (void)testNormalizeTagsWhitespaceRemoval {
    NSArray *tags = @[@"   tag-one   ", @"tag-two   "];
    NSArray *tagsNoSpaces = @[@"tag-one", @"tag-two"];
    [self.push normalizeTags:tags];
    
    XCTAssertEqualObjects(tagsNoSpaces, [self.push normalizeTags:tags], @"whitespace was not trimmed from tags");
}

- (void)testNormalizeTagsMaxTagSize {
    NSArray *tags = @[[@"" stringByPaddingToLength:127 withString: @"." startingAtIndex:0]];
    
    XCTAssertEqualObjects(tags, [self.push normalizeTags:tags], @"tag with 127 characters should set");
}


- (void)testNormalizeTagsOverMaxTagSizeRemoval {
    NSArray *tags = @[[@"" stringByPaddingToLength:128 withString: @"." startingAtIndex:0]];
    [self.push normalizeTags:tags];
    
    XCTAssertNotEqualObjects(tags, [self.push normalizeTags:tags], @"tag with 128 characters should not set");
}


- (void)testAddTagsToCurrentDevice {
    self.push.tags = nil;

    [self.push addTagsToCurrentDevice:@[@"tag-one", @"tag-two"]];
    XCTAssertEqualObjects([NSSet setWithArray:(@[@"tag-one", @"tag-two"])], [NSSet setWithArray:self.push.tags],
                          @"Add tags to current device fails when no existing tags exist");

    // Try to add same tags again
    [self.push addTagsToCurrentDevice:@[@"tag-one", @"tag-two"]];
    XCTAssertEqual((NSUInteger)2, self.push.tags.count, @"Add tags should not add duplicate tags");


    // Try to add a new set of tags, with one of the tags being unique
    [self.push addTagsToCurrentDevice:@[@"tag-one", @"tag-three"]];

    XCTAssertEqual((NSUInteger)3, self.push.tags.count,
                   @"Add tags should add unique tags even if some of them are duplicate");

    XCTAssertEqualObjects([NSSet setWithArray:(@[@"tag-one", @"tag-two", @"tag-three"])], [NSSet setWithArray:self.push.tags],
                          @"Add tags should add unique tags even if some of them are duplicate");

    // Try to add an nil set of tags
    XCTAssertNoThrow([self.push addTagsToCurrentDevice:nil],
                     @"Should not throw when adding a nil set of tags");

    // Try to add an nil set of tags
    XCTAssertNoThrow([self.push addTagsToCurrentDevice:[NSArray array]],
                     @"Should not throw when adding an empty tag array");
}

- (void)testAddTagToCurrentDevice {
    self.push.tags = nil;

    [self.push addTagToCurrentDevice:@"tag-one"];
    XCTAssertEqualObjects((@[@"tag-one"]), self.push.tags,
                          @"Add tag to current device fails when no existing tags exist");

    // Try to add same tag again
    [self.push addTagToCurrentDevice:@"tag-one"];
    XCTAssertEqual((NSUInteger)1, self.push.tags.count, @"Add tag should not add duplicate tags");

    // Add a new tag
    [self.push addTagToCurrentDevice:@"tag-two"];
    XCTAssertEqualObjects((@[@"tag-one", @"tag-two"]), self.push.tags,
                          @"Adding another tag to tags fails");

    // Try to add an nil tag
    XCTAssertThrows([self.push addTagToCurrentDevice:nil],
                    @"Should throw when adding a nil tag");
}

- (void)testRemoveTagFromCurrentDevice {
    self.push.tags = nil;
    XCTAssertNoThrow([self.push removeTagFromCurrentDevice:@"some-tag"],
                     @"Should not throw when removing a tag when tags are empty");

    self.push.tags = @[@"some-tag", @"some-other-tag"];
    XCTAssertNoThrow([self.push removeTagFromCurrentDevice:@"some-not-found-tag"],
                     @"Should not throw when removing a tag that does not exist");

    [self.push removeTagFromCurrentDevice:@"some-tag"];
    XCTAssertEqualObjects((@[@"some-other-tag"]), self.push.tags,
                          @"Remove tag from device should actually remove the tag");

    XCTAssertThrows([self.push removeTagFromCurrentDevice:nil],
                    @"Should throw when removing a nil tag");
}

- (void)testRemoveTagsFromCurrentDevice {
    self.push.tags = nil;
    XCTAssertNoThrow([self.push removeTagsFromCurrentDevice:@[@"some-tag"]],
                     @"Should not throw when removing tags when current tags are empty");

    self.push.tags = @[@"some-tag", @"some-other-tag"];
    XCTAssertNoThrow([self.push removeTagsFromCurrentDevice:@[@"some-not-found-tag"]],
                     @"Should not throw when removing tags that do not exist");

    [self.push removeTagsFromCurrentDevice:@[@"some-tag"]];
    XCTAssertEqualObjects((@[@"some-other-tag"]), self.push.tags,
                          @"Remove tags from device should actually remove the tag");

    XCTAssertNoThrow([self.push removeTagsFromCurrentDevice:nil],
                     @"Should throw when removing a nil set of tags");
}

- (void)testPushEnabledToYes {
    self.push.pushEnabled = NO;

    // Make sure push is set to NO
    XCTAssertFalse(self.push.pushEnabled, @"pushEnabled should default to NO");

    // Set the notificationTypes so we know what to expect when it registers
    self.push.notificationTypes = UIRemoteNotificationTypeAlert;

    [[self.mockedApplication expect] registerForRemoteNotificationTypes:UIRemoteNotificationTypeAlert];

    self.push.pushEnabled = YES;

    XCTAssertTrue(self.push.pushEnabled,
                  @"pushEnabled should be enabled when set to YES");

    XCTAssertTrue([[NSUserDefaults standardUserDefaults] boolForKey:UAPushEnabledSettingsKey],
                  @"pushEnabled should be stored in standardUserDefaults");

    XCTAssertNoThrow([self.mockedApplication verify],
                     @"pushEnabled should register for remote notifications");
}

- (void)testPushEnabledToNo {
    self.push.deviceToken = validDeviceToken;
    self.push.pushEnabled = YES;

    // Add a device token so we get a device api callback
    [[self.mockedDeviceRegistrar expect] registerPushDisabledWithChannelID:OCMOCK_ANY
                                                           channelLocation:OCMOCK_ANY
                                                               withPayload:OCMOCK_ANY
                                                                forcefully:NO];

    [[self.mockedApplication expect] registerForRemoteNotificationTypes:UIRemoteNotificationTypeNone];
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];


    self.push.pushEnabled = NO;

    XCTAssertFalse(self.push.pushEnabled,
                   @"pushEnabled should be disabled when set to NO");

    XCTAssertFalse([[NSUserDefaults standardUserDefaults] boolForKey:UAPushEnabledSettingsKey],
                   @"pushEnabled should be stored in standardUserDefaults");

    XCTAssertNoThrow([self.mockedApplication verify],
                     @"pushEnabled should unregister for remote notifications");

    XCTAssertNoThrow([self.mockedDeviceRegistrar verify],
                     @"pushEnabled should make unregister with the device api client");
}

- (void)testSetQuietTime {
    [self.push setQuietTimeStartHour:12 startMinute:30 endHour:14 endMinute:58];

    NSDictionary *quietTime = self.push.quietTime;
    XCTAssertEqualObjects(@"12:30", [quietTime valueForKey:UAPushQuietTimeStartKey],
                          @"Quiet time start is not set correctly");

    XCTAssertEqualObjects(@"14:58", [quietTime valueForKey:UAPushQuietTimeEndKey],
                          @"Quiet time end is not set correctly");

    // Change the time zone
    self.push.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:-3600*3];

    // Make sure the hour and minutes are still the same
    quietTime = self.push.quietTime;
    XCTAssertEqualObjects(@"12:30", [quietTime valueForKey:UAPushQuietTimeStartKey],
                          @"Quiet time start is not set correctly");

    XCTAssertEqualObjects(@"14:58", [quietTime valueForKey:UAPushQuietTimeEndKey],
                          @"Quiet time end is not set correctly");


    // Try to set it to an invalid start hour
    [self.push setQuietTimeStartHour:24 startMinute:30 endHour:14 endMinute:58];

    // Make sure the hour and minutes are still the same
    quietTime = self.push.quietTime;
    XCTAssertEqualObjects(@"12:30", [quietTime valueForKey:UAPushQuietTimeStartKey],
                          @"Quiet time start is not set correctly");

    XCTAssertEqualObjects(@"14:58", [quietTime valueForKey:UAPushQuietTimeEndKey],
                          @"Quiet time end is not set correctly");

    // Try to set it to an invalid end minute
    [self.push setQuietTimeStartHour:12 startMinute:30 endHour:14 endMinute:60];

    // Make sure the hour and minutes are still the same
    quietTime = self.push.quietTime;
    XCTAssertEqualObjects(@"12:30", [quietTime valueForKey:UAPushQuietTimeStartKey],
                          @"Quiet time start is not set correctly");

    XCTAssertEqualObjects(@"14:58", [quietTime valueForKey:UAPushQuietTimeEndKey],
                          @"Quiet time end is not set correctly");
}

- (void)testSetQuietTimeDeprecated {
    NSDate *start = [NSDate dateWithTimeIntervalSince1970:60]; // 0:01 GMT
    NSDate *end = [NSDate dateWithTimeIntervalSince1970:60 * 60 * 13]; // 13:00 GMT

    [self.push setQuietTimeFrom:start
                                   to:end
                         withTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"]];

    XCTAssertEqualObjects(@"GMT", [self.push.timeZone abbreviation],
                          @"Timezone should be set to the timezone in quiet time");

    NSDictionary *quietTime = self.push.quietTime;
    XCTAssertEqualObjects(@"0:01", [quietTime valueForKey:UAPushQuietTimeStartKey],
                          @"Quiet time start is not set correctly");
    XCTAssertEqualObjects(@"13:00", [quietTime valueForKey:UAPushQuietTimeEndKey],
                          @"Quiet time end is not set correctly");


    // Test setting timezone to -5 GMT
    [self.push setQuietTimeFrom:start
                                   to:end
                         withTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:-3600*5]];

    quietTime = self.push.quietTime;
    XCTAssertEqualObjects(@"19:01", [quietTime valueForKey:UAPushQuietTimeStartKey],
                          @"Quiet time start is not set handling timezone to -5 GMT correctly");

    XCTAssertEqualObjects(@"8:00", [quietTime valueForKey:UAPushQuietTimeEndKey],
                          @"Quiet time end is not set handling timezone to -5 GMT correctly");
}

- (void)testSetQuietTimeDeprecatedNoTimeZone {
    NSDate *start = [NSDate dateWithTimeIntervalSince1970:60]; // 0:01 GMT
    NSDate *end = [NSDate dateWithTimeIntervalSince1970:60 * 60 * 13]; // 13:00 GMT

    // Set the current timezone to CDT
    self.push.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"CDT"];

    // When timezone is nil, it uses whatever defaultQuietTimeZone is, then sets it to timezone
    [self.push setQuietTimeFrom:start to:end withTimeZone:nil];

    XCTAssertEqualObjects([self.push.defaultTimeZoneForQuietTime abbreviation],
                          [self.push.timeZone abbreviation],
                          @"Timezone should be set to defaultTimeZoneForQuietTime");
}

- (void)testTimeZone {
    self.push.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"EST"];

    XCTAssertEqualObjects([NSTimeZone timeZoneWithAbbreviation:@"EST"],
                          self.push.timeZone,
                          @"timezone is not being set correctly");

    XCTAssertEqualObjects([[NSTimeZone timeZoneWithAbbreviation:@"EST"] name],
                          [[NSUserDefaults standardUserDefaults] stringForKey:UAPushTimeZoneSettingsKey],
                          @"timezone should be stored in standardUserDefaults");

    self.push.timeZone = nil;

    XCTAssertEqualObjects([self.push.defaultTimeZoneForQuietTime abbreviation],
                          [self.push.timeZone abbreviation],
                          @"Timezone should default to defaultTimeZoneForQuietTime");

    XCTAssertNil([[NSUserDefaults standardUserDefaults] stringForKey:UAPushTimeZoneSettingsKey],
                 @"timezone should be able to be cleared in standardUserDefaults");
}

- (void)testRegisterForRemoteNotificationsPushEnabled {
    self.push.pushEnabled = YES;
    self.push.notificationTypes = UIRemoteNotificationTypeSound;

    [[self.mockedApplication expect] registerForRemoteNotificationTypes:UIRemoteNotificationTypeSound];
    [self.push registerForRemoteNotifications];

    XCTAssertNoThrow([self.mockedApplication verify],
                     @"should register for push notification types when push is enabled");

}

- (void)testRegisterForRemoteNotificationsPushDisabled {
    self.push.pushEnabled = NO;
    self.push.notificationTypes = UIRemoteNotificationTypeSound;

    [[self.mockedApplication reject] registerForRemoteNotificationTypes:UIRemoteNotificationTypeSound];
    [self.push registerForRemoteNotifications];

    XCTAssertNoThrow([self.mockedApplication verify],
                     @"should not register for push notification types when push is disabled");
}

- (void)testRegisterForRemoteNotificationTypesPushEnabled {
    self.push.pushEnabled = YES;
    self.push.notificationTypes = UIRemoteNotificationTypeSound;

    [[self.mockedApplication expect] registerForRemoteNotificationTypes:UIRemoteNotificationTypeBadge];
    [self.push registerForRemoteNotificationTypes:UIRemoteNotificationTypeBadge];

    XCTAssertNoThrow([self.mockedApplication verify],
                     @"should register for push notification types when push is enabled");

    XCTAssertEqual(UIRemoteNotificationTypeBadge, self.push.notificationTypes,
                   @"registerForPushNotificationTypes should still set the notificationTypes when push is enabled");
}

- (void)testRegisterForRemoteNotificationTypesPushDisabled {
    self.push.notificationTypes = UIRemoteNotificationTypeSound;
    self.push.pushEnabled = NO;

    [[self.mockedApplication reject] registerForRemoteNotificationTypes:UIRemoteNotificationTypeBadge];
    [self.push registerForRemoteNotificationTypes:UIRemoteNotificationTypeBadge];

    XCTAssertNoThrow([self.mockedApplication verify],
                     @"should not register for push notification types when push is disabled");

    XCTAssertEqual(UIRemoteNotificationTypeBadge, self.push.notificationTypes,
                   @"registerForPushNotificationTypes should still set the notificationTypes when push is disabled");
}

- (void)testSetBadgeNumberAutoBadgeEnabled{
    // Set the right values so we can check if a device api client call was made or not
    self.push.pushEnabled = YES;
    self.push.autobadgeEnabled = YES;
    self.push.deviceToken = validDeviceToken;

    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE((NSInteger)30)] applicationIconBadgeNumber];
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    [[self.mockedApplication expect] setApplicationIconBadgeNumber:15];
    [[self.mockedDeviceRegistrar expect] registerWithChannelID:OCMOCK_ANY
                                               channelLocation:OCMOCK_ANY
                                                   withPayload:OCMOCK_ANY
                                                    forcefully:YES];

    [self.push setBadgeNumber:15];
    XCTAssertNoThrow([self.mockedApplication verify],
                     @"should update application icon badge number when its different");

    XCTAssertNoThrow([self.mockedDeviceRegistrar verify],
                     @"should update registration so autobadge works");
}

- (void)testSetBadgeNumberNoChange {
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE((NSInteger)30)] applicationIconBadgeNumber];
    [[self.mockedApplication reject] setApplicationIconBadgeNumber:30];

    [self.push setBadgeNumber:30];
    XCTAssertNoThrow([self.mockedApplication verify],
                     @"should not update application icon badge number if there is no change");
}

- (void)testSetBadgeNumberAutoBadgeDisabled {
    self.push.pushEnabled = YES;
    self.push.deviceToken = validDeviceToken;

    self.push.autobadgeEnabled = NO;

    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE((NSInteger)30)] applicationIconBadgeNumber];
    [[self.mockedApplication expect] setApplicationIconBadgeNumber:15];

    // Reject device api client registration because autobadge is not enabled
    [[self.mockedDeviceRegistrar reject] registerWithChannelID:OCMOCK_ANY
                                               channelLocation:OCMOCK_ANY
                                                   withPayload:OCMOCK_ANY
                                                    forcefully:YES];
    [self.push setBadgeNumber:15];
    XCTAssertNoThrow([self.mockedApplication verify],
                     @"should update application icon badge number when its different");

    XCTAssertNoThrow([self.mockedDeviceRegistrar verify],
                     @"should not update registration because autobadge is disabled");
}

- (void)testRegisterDeviceToken {
    self.push.notificationTypes = UIRemoteNotificationTypeSound;
    self.push.pushEnabled = YES;
    self.push.deviceToken = nil;

    NSData *token = [@"some-token" dataUsingEncoding:NSASCIIStringEncoding];
    [[self.mockedAnalytics expect] addEvent:OCMOCK_ANY];

    [[self.mockedDeviceRegistrar expect] registerWithChannelID:OCMOCK_ANY
                                               channelLocation:OCMOCK_ANY
                                                   withPayload:OCMOCK_ANY
                                                    forcefully:NO];

    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    [self.push registerDeviceToken:token];

    XCTAssertNoThrow([self.mockedAnalytics verify],
                     @"should add device registration event to analytics");

    XCTAssertNoThrow([self.mockedDeviceRegistrar verify],
                     @"should update registration on registering device token");

    // 736f6d652d746f6b656e = "some-token" in hex
    XCTAssertEqualObjects(@"736f6d652d746f6b656e", self.push.deviceToken, @"Register device token should set the device token");
}

/**
 * Test registering a device token in the background does not
 * update registration if we already have a channel
 */
- (void)testRegisterDeviceTokenBackground {
    self.push.notificationTypes = UIRemoteNotificationTypeSound;
    self.push.pushEnabled = YES;
    self.push.deviceToken = nil;
    self.push.channelID = @"channel";

    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateBackground)] applicationState];


    NSData *token = [@"some-token" dataUsingEncoding:NSASCIIStringEncoding];
    [[self.mockedAnalytics expect] addEvent:OCMOCK_ANY];

    [[self.mockedDeviceRegistrar reject] registerWithChannelID:OCMOCK_ANY
                                               channelLocation:OCMOCK_ANY
                                                   withPayload:OCMOCK_ANY
                                                    forcefully:NO];

    [self.push registerDeviceToken:token];

    XCTAssertNoThrow([self.mockedAnalytics verify],
                     @"should add device registration event to analytics");

    XCTAssertNoThrow([self.mockedDeviceRegistrar verify],
                     @"should not allow registration in background except for channel creation");

    // 736f6d652d746f6b656e = "some-token" in hex
    XCTAssertEqualObjects(@"736f6d652d746f6b656e", self.push.deviceToken, @"Register device token should set the device token");
}

/**
 * Test registering a device token in the background does not
 * update registration if we are using device registration
 */
- (void)testRegisterDeviceTokenBackgroundDeviceRegistration {
    self.push.notificationTypes = UIRemoteNotificationTypeSound;
    self.push.pushEnabled = YES;
    self.push.deviceToken = nil;

    [[[self.mockedDeviceRegistrar stub] andReturnValue:OCMOCK_VALUE(NO)] isUsingChannelRegistration];
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateBackground)] applicationState];


    NSData *token = [@"some-token" dataUsingEncoding:NSASCIIStringEncoding];
    [[self.mockedAnalytics expect] addEvent:OCMOCK_ANY];

    [[self.mockedDeviceRegistrar reject] registerWithChannelID:OCMOCK_ANY
                                               channelLocation:OCMOCK_ANY
                                                   withPayload:OCMOCK_ANY
                                                    forcefully:NO];

    [self.push registerDeviceToken:token];

    XCTAssertNoThrow([self.mockedAnalytics verify],
                     @"should add device registration event to analytics");

    XCTAssertNoThrow([self.mockedDeviceRegistrar verify],
                     @"should not allow registration in background except for channel creation");

    // 736f6d652d746f6b656e = "some-token" in hex
    XCTAssertEqualObjects(@"736f6d652d746f6b656e", self.push.deviceToken, @"Register device token should set the device token");
}

/**
 * Test device token registration in the background updates registration for
 * channel creation.
 */
- (void)testRegisterDeviceTokenBackgroundChannelCreation {
    self.push.notificationTypes = UIRemoteNotificationTypeSound;
    self.push.pushEnabled = YES;
    self.push.deviceToken = nil;
    self.push.channelID = nil;

    [[[self.mockedDeviceRegistrar stub] andReturnValue:OCMOCK_VALUE(YES)] isUsingChannelRegistration];
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateBackground)] applicationState];
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];


    NSData *token = [@"some-token" dataUsingEncoding:NSASCIIStringEncoding];
    [[self.mockedAnalytics expect] addEvent:OCMOCK_ANY];

    [[self.mockedDeviceRegistrar expect] registerWithChannelID:OCMOCK_ANY
                                               channelLocation:OCMOCK_ANY
                                                   withPayload:OCMOCK_ANY
                                                    forcefully:NO];

    [self.push registerDeviceToken:token];

    XCTAssertNoThrow([self.mockedAnalytics verify],
                     @"should add device registration event to analytics");

    XCTAssertNoThrow([self.mockedDeviceRegistrar verify],
                     @"should update registration on registering device token");

    // 736f6d652d746f6b656e = "some-token" in hex
    XCTAssertEqualObjects(@"736f6d652d746f6b656e", self.push.deviceToken, @"Register device token should set the device token");
}

- (void)testRegisterDeviceTokenNoNotificationTypes {
    self.push.notificationTypes = 0;
    self.push.pushEnabled = YES;
    self.push.deviceToken = nil;

    NSData *token = [@"some-token" dataUsingEncoding:NSASCIIStringEncoding];
    [[self.mockedAnalytics reject] addEvent:OCMOCK_ANY];
    [[self.mockedDeviceRegistrar reject] registerWithChannelID:OCMOCK_ANY
                                               channelLocation:OCMOCK_ANY
                                                   withPayload:OCMOCK_ANY
                                                    forcefully:NO];
    [self.push registerDeviceToken:token];

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
    self.push.pushEnabled = YES;
    self.push.deviceToken = validDeviceToken;

    // Check every app state.  We want to allow manual registration in any state.
    for(int i = UIApplicationStateActive; i < UIApplicationStateBackground; i++) {
        UIApplicationState state = (UIApplicationState)i;
        self.push.registrationBackgroundTask = UIBackgroundTaskInvalid;

        [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(state)] applicationState];

        [[self.mockedDeviceRegistrar expect] registerWithChannelID:OCMOCK_ANY
                                                   channelLocation:OCMOCK_ANY
                                                       withPayload:OCMOCK_ANY
                                                        forcefully:YES];

        [[[self.mockedApplication expect] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

        [self.push updateRegistrationForcefully:YES];
        XCTAssertNoThrow([self.mockedDeviceRegistrar verify],
                         @"updateRegistration should register with the device registrar if push is enabled.");

        XCTAssertNoThrow([self.mockedApplication verify], @"A background task should be requested for every update");
    }
}


- (void)testUpdateRegistrationForcefullyPushDisabled {
    self.push.pushEnabled = NO;
    self.push.deviceToken = validDeviceToken;

    [[self.mockedDeviceRegistrar expect] registerPushDisabledWithChannelID:OCMOCK_ANY
                                                           channelLocation:OCMOCK_ANY
                                                               withPayload:OCMOCK_ANY
                                                                forcefully:YES];

    [[[self.mockedApplication expect] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];


    [self.push updateRegistrationForcefully:YES];
    XCTAssertNoThrow([self.mockedDeviceRegistrar verify],
                     @"updateRegistration should unregister with the device registrar if push is disabled.");

    XCTAssertNoThrow([self.mockedApplication verify], @"A background task should be requested for every update");
}

- (void)testUpdateRegistrationInvalidBackgroundTask {
    self.push.pushEnabled = YES;
    self.push.deviceToken = validDeviceToken;

    [[[self.mockedApplication expect] andReturnValue:OCMOCK_VALUE((NSUInteger)UIBackgroundTaskInvalid)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    [[self.mockedDeviceRegistrar reject] registerWithChannelID:OCMOCK_ANY
                                               channelLocation:OCMOCK_ANY
                                                   withPayload:OCMOCK_ANY
                                                    forcefully:YES];

    [self.push updateRegistrationForcefully:YES];


    XCTAssertNoThrow([self.mockedDeviceRegistrar verify],
                     @"updateRegistration should not call any registration without a valid background task");
}

- (void)testUpdateRegistrationExistingBackgroundTask {
    self.push.registrationBackgroundTask = 30;
    [[self.mockedApplication reject] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    [self.push updateRegistrationForcefully:YES];

    XCTAssertNoThrow([self.mockedApplication verify], @"A background task should not be requested if one already exists");
}

- (void)testRegistrationPayload {
    // Set up UAPush to give a full, opted in payload
    self.push.deviceToken = validDeviceToken;
    self.push.alias = @"ALIAS";
    self.push.deviceTagsEnabled = YES;
    self.push.tags = @[@"tag-one"];
    self.push.autobadgeEnabled = NO;
    self.push.quietTimeEnabled = YES;
    [self.push setQuietTimeFrom:[NSDate dateWithTimeIntervalSince1970:0]
                                   to:[NSDate dateWithTimeIntervalSince1970:10]
                         withTimeZone:[NSTimeZone timeZoneWithName:@"Pacific/Auckland"]];

    // Opt in requirements
    self.push.pushEnabled = YES;
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

    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];
    [[self.mockedDeviceRegistrar expect] registerWithChannelID:OCMOCK_ANY
                                               channelLocation:OCMOCK_ANY
                                                   withPayload:[OCMArg checkWithBlock:checkPayloadBlock]
                                                    forcefully:YES];

    [self.push updateRegistrationForcefully:YES];

    XCTAssertNoThrow([self.mockedDeviceRegistrar verify],
                     @"payload is not being created with expected values");
}

- (void)testRegistrationPayloadNoDeviceToken {
    // Set up UAPush to give minimum payload
    self.push.deviceToken = nil;
    self.push.alias = nil;
    self.push.deviceTagsEnabled = NO;
    self.push.autobadgeEnabled = NO;
    self.push.quietTimeEnabled = NO;

    // Opt in requirements
    self.push.pushEnabled = YES;
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

    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];
    [[self.mockedDeviceRegistrar expect] registerWithChannelID:OCMOCK_ANY channelLocation:OCMOCK_ANY withPayload:[OCMArg checkWithBlock:checkPayloadBlock] forcefully:YES];

    [self.push updateRegistrationForcefully:YES];

    XCTAssertNoThrow([self.mockedDeviceRegistrar verify],
                     @"payload is not being created with expected values");

}

- (void)testRegistrationPayloadDeviceTagsDisabled {
    self.push.pushEnabled = YES;
    self.push.deviceTagsEnabled = NO;
    self.push.tags = @[@"tag-one"];

    // Check that the payload setTags is NO and the tags is nil
    BOOL (^checkPayloadBlock)(id obj) = ^(id obj) {
        UAChannelRegistrationPayload *payload = obj;
        return (BOOL)(!payload.setTags && payload.tags == nil);
    };

    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];
    [[self.mockedDeviceRegistrar expect] registerWithChannelID:OCMOCK_ANY
                                               channelLocation:OCMOCK_ANY
                                                   withPayload:[OCMArg checkWithBlock:checkPayloadBlock]
                                                    forcefully:YES];

    [self.push updateRegistrationForcefully:YES];

    XCTAssertNoThrow([self.mockedDeviceRegistrar verify],
                     @"payload is including tags when device tags is NO");

}

- (void)testRegistrationPayloadAutoBadgeEnabled {
    self.push.pushEnabled = YES;
    self.push.autobadgeEnabled = YES;
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE((NSInteger)30)] applicationIconBadgeNumber];

    // Check that the payload setTags is NO and the tags is nil
    BOOL (^checkPayloadBlock)(id obj) = ^(id obj) {
        UAChannelRegistrationPayload *payload = obj;
        return (BOOL)([payload.badge integerValue] == 30);
    };

    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];
    [[self.mockedDeviceRegistrar expect] registerWithChannelID:OCMOCK_ANY
                                               channelLocation:OCMOCK_ANY
                                                   withPayload:[OCMArg checkWithBlock:checkPayloadBlock]
                                                    forcefully:YES];

    [self.push updateRegistrationForcefully:YES];

    XCTAssertNoThrow([self.mockedDeviceRegistrar verify],
                     @"payload is not including the correct badge when auto badge is enabled");
}

- (void)testRegistrationPayloadNoQuietTime {
    self.push.pushEnabled = YES;
    self.push.quietTimeEnabled = NO;
    [self.push setQuietTimeFrom:[NSDate dateWithTimeIntervalSince1970:0]
                                   to:[NSDate dateWithTimeIntervalSince1970:10]
                         withTimeZone:[NSTimeZone timeZoneWithName:@"Pacific/Auckland"]];


    // Check that the payload does not include a quiet time
    BOOL (^checkPayloadBlock)(id obj) = ^(id obj) {
        UAChannelRegistrationPayload *payload = obj;
        return (BOOL)(payload.quietTime == nil);
    };

    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];
    [[self.mockedDeviceRegistrar expect] registerWithChannelID:OCMOCK_ANY
                                               channelLocation:OCMOCK_ANY
                                                   withPayload:[OCMArg checkWithBlock:checkPayloadBlock]
                                                    forcefully:YES];

    [self.push updateRegistrationForcefully:YES];

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
        [[self.mockedAnalytics expect] handleNotification:self.notification inApplicationState:applicationState];
        [self.push handleNotification:self.notification applicationState:applicationState];

        XCTAssertNoThrow([self.mockActionRunner verify], @"handleNotification should run push actions with situation %ld", expectedSituation);
        XCTAssertNoThrow([self.mockedAnalytics verify], @"analytics should be notified of the incoming notification");

        // Test handleNotification:fetchCompletionHandler: for every background fetch result
        for (int fetchResultIndex = 0; fetchResultIndex < 3; fetchResultIndex++) {
            __block BOOL completionHandlerCalled = NO;
            fetchResult = fetchResults[fetchResultIndex];

            [[self.mockActionRunner expect] runActions:[OCMArg checkWithBlock:runActionsCheck] withCompletionHandler:[OCMArg checkWithBlock:handlerCheck]];
            [[self.mockedAnalytics expect] handleNotification:self.notification inApplicationState:applicationState];
            [self.push handleNotification:self.notification applicationState:applicationState fetchCompletionHandler:^(UIBackgroundFetchResult result) {
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
    [self.push handleNotification:self.notification applicationState:UIApplicationStateActive];
    [self.push handleNotification:self.notification applicationState:UIApplicationStateBackground];
    [self.push handleNotification:self.notification applicationState:UIApplicationStateInactive];

    XCTAssertNoThrow([self.mockedApplication verify], @"Badge should only be updated if autobadge is enabled");
}

/**
 * Test handleNotification when auto badge is enabled sets the badge
 * only when a notification comes in while the app is in the foreground
 */
- (void)testHandleNotificationAutoBadgeEnabled {
    UAPush.shared.autobadgeEnabled = YES;

    [[self.mockedApplication expect] setApplicationIconBadgeNumber:2];
    [self.push handleNotification:self.notification applicationState:UIApplicationStateActive];

    XCTAssertNoThrow([self.mockedApplication verify], @"Badge should be updated if app is in the foreground");

    [[self.mockedApplication reject] setApplicationIconBadgeNumber:2];
    [self.push handleNotification:self.notification applicationState:UIApplicationStateBackground];
    [self.push handleNotification:self.notification applicationState:UIApplicationStateInactive];

    XCTAssertNoThrow([self.mockedApplication verify], @"Badge should only be updated if app is in the foreground");
}

/**
 * Test handleNotification in an inactive state sets the launchNotification  
 */
- (void)testHandleNotificationLaunchNotification {
    self.push.launchNotification = nil;
    [self.push handleNotification:self.notification applicationState:UIApplicationStateActive];
    [self.push handleNotification:self.notification applicationState:UIApplicationStateBackground];

    XCTAssertNil(self.push.launchNotification, @"Launch notification should only be set in an inactive state");

    [self.push handleNotification:self.notification applicationState:UIApplicationStateInactive];
    XCTAssertNotNil(self.push.launchNotification, @"Launch notification should be set in an inactive state");
}

/**
 * Test applicationDidEnterBackground clears the notification and sets 
 * the hasEnteredBackground flag
 */
- (void)testApplicationDidEnterBackground {
    UAPush *push = self.push;
    push.hasEnteredBackground = NO;
    push.launchNotification = self.notification;

    [push applicationDidEnterBackground];
    XCTAssertTrue(push.hasEnteredBackground, @"applicationDidEnterBackground should set hasEnteredBackground to true");
    XCTAssertNil(push.launchNotification, @"applicationDidEnterBackground should clear the launch notification");
    XCTAssertTrue([[NSUserDefaults standardUserDefaults] boolForKey:UAPushChannelCreationOnForeground], @"applicationDidEnterBackground should set channelCreationOnForeground to true");
}

/**
 * Test update registartion is called when the device enters a background and
 * we do not have a channel id
 */
- (void)testApplicationDidEnterBackgroundCreatesChannel {
    self.push.channelID = nil;
    [[[self.mockedDeviceRegistrar stub] andReturnValue:OCMOCK_VALUE(YES)] isUsingChannelRegistration];

    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    [[self.mockedDeviceRegistrar expect] registerWithChannelID:OCMOCK_ANY
                                               channelLocation:OCMOCK_ANY
                                                   withPayload:OCMOCK_ANY
                                                    forcefully:NO];

    [self.push applicationDidEnterBackground];

    XCTAssertNoThrow([self.mockedDeviceRegistrar verify], @"Channel registration should be called");
}

/**
 * Test channel created
 */
- (void)testChannelCreated {
    UAPush *push = self.push;

    [push channelCreated:@"someChannelID" channelLocation:@"someLocation"];

    XCTAssertEqualObjects(push.channelID, @"someChannelID", @"The channel ID should be set on channel creation.");
    XCTAssertEqualObjects(push.channelLocation, @"someLocation", @"The channel location should be set on channel creation.");
}

/**
 * Test registration succeeded with channels and an up to date payload
 */
- (void)testRegistrationSucceeded {
    self.push.deviceToken = validDeviceToken;
    self.push.channelID = @"someChannelID";
    self.push.registrationBackgroundTask = 30;
    [[[self.mockedDeviceRegistrar stub] andReturnValue:OCMOCK_VALUE(YES)] isUsingChannelRegistration];

    [[self.mockRegistrationDelegate expect] registrationSucceededForChannelID:@"someChannelID" deviceToken:validDeviceToken];

    [[self.mockedApplication expect] endBackgroundTask:30];

    [self.push registrationSucceededWithPayload:[self.push createChannelPayload]];
    XCTAssertNoThrow([self.mockRegistrationDelegate verify], @"Delegate should be called");
    XCTAssertNoThrow([self.mockedApplication verify], @"Should end the background task");
}

/**
 * Test registration succeeded with an out of date payload
 */
- (void)testRegistrationSucceededUpdateNeeded {
    self.push.deviceToken = validDeviceToken;
    self.push.channelID = @"someChannelID";
    self.push.registrationBackgroundTask = 30;

    [[[self.mockedDeviceRegistrar stub] andReturnValue:OCMOCK_VALUE(YES)] isUsingChannelRegistration];

    [[self.mockRegistrationDelegate expect] registrationSucceededForChannelID:@"someChannelID" deviceToken:validDeviceToken];

    [[self.mockedDeviceRegistrar expect] registerWithChannelID:OCMOCK_ANY
                                               channelLocation:OCMOCK_ANY
                                                   withPayload:OCMOCK_ANY
                                                    forcefully:NO];

    // Should not end the background task
    [[self.mockedApplication reject] endBackgroundTask:30];

    // Call with an empty payload.  Should be different then the UAPush generated payload
    [self.push registrationSucceededWithPayload:[[UAChannelRegistrationPayload alloc] init]];

    XCTAssertNoThrow([self.mockRegistrationDelegate verify], @"Delegate should be called");
    XCTAssertNoThrow([self.mockedApplication verify], @"Should not end the background task");
}

/**
 * Test registration succeeded when using device registration and the 
 */
- (void)testRegistartionSucceededDeviceRegistartionUpdate {
    self.push.deviceToken = validDeviceToken;
    [[[self.mockedDeviceRegistrar stub] andReturnValue:OCMOCK_VALUE(NO)] isUsingChannelRegistration];
    self.push.registrationBackgroundTask = 30;

    // Make push enabled not match isDeviceTokenRegistered
    self.push.pushEnabled = NO;
    [[[self.mockedDeviceRegistrar stub] andReturnValue:OCMOCK_VALUE(YES)] isDeviceTokenRegistered];

    [[self.mockRegistrationDelegate expect] registrationSucceededForChannelID:@"someChannelID" deviceToken:validDeviceToken];

    [[self.mockedDeviceRegistrar expect] registerPushDisabledWithChannelID:OCMOCK_ANY
                                                           channelLocation:OCMOCK_ANY
                                                               withPayload:OCMOCK_ANY
                                                                forcefully:NO];

    // Should not end the background task
    [[self.mockedApplication reject] endBackgroundTask:30];

    // Call with an empty payload.  Should be different then the UAPush generated payload
    [self.push registrationSucceededWithPayload:[[UAChannelRegistrationPayload alloc] init]];

    XCTAssertNoThrow([self.mockRegistrationDelegate verify], @"Delegate should be called");
    XCTAssertNoThrow([self.mockedApplication verify], @"Should not end the background task");
}


/**
 * Test registration failed
 */
- (void)testRegistrationFailed {
    self.push.registrationBackgroundTask = 30;

    [[self.mockRegistrationDelegate expect] registrationFailed];
    [[self.mockedApplication expect] endBackgroundTask:30];

    [self.push registrationFailedWithPayload:[[UAChannelRegistrationPayload alloc] init]];
    XCTAssertNoThrow([self.mockRegistrationDelegate verify], @"Delegate should be called");
    XCTAssertNoThrow([self.mockedApplication verify], @"Should end the background task");
}

/**
 * Test setting the channel ID generates the device registration event with the
 * channel ID.
 */
- (void)testSetChannelID {
    self.push.channelID = @"someChannelID";

    XCTAssertEqualObjects(@"someChannelID", self.push.channelID, @"Channel ID is not being set properly");
}

@end
