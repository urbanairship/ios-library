/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
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
#import "UAirship.h"
#import "UAAnalytics.h"
#import "UAirship+Internal.h"
#import "UAActionRunner+Internal.h"
#import "UAActionRegistry+Internal.h"
#import "UAUtils.h"
#import "UAUser.h"
#import "UAChannelRegistrationPayload+Internal.h"
#import "UAChannelRegistrar+Internal.h"
#import "UAEvent.h"
#import "NSObject+HideClass.h"
#import "UAInteractiveNotificationEvent+Internal.h"
#import "UANotificationCategories+Internal.h"
#import "UANotificationAction.h"
#import "UANotificationCategory.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAConfig.h"
#import "UATagGroupsAPIClient+Internal.h"
#import "UANotificationCategory+Internal.h"
#import "UAPushReceivedEvent+Internal.h"
#import "UATagGroupsMutation+Internal.h"

@interface UATestNotificationObserver : NSObject
@property(nonatomic, copy) void (^block)(NSNotification *);
@end

@implementation UATestNotificationObserver

- (instancetype)initWithBlock:(void (^)(NSNotification *))block {
    self = [super init];
    if (self) {
        self.block = block;
    }

    return self;
}

- (void)handleNotification:(NSNotification *)notification {
    self.block(notification);
}

@end

@interface UAPushTest : XCTestCase
@property (nonatomic, strong) id mockedApplication;
@property (nonatomic, strong) id mockedChannelRegistrar;
@property (nonatomic, strong) id mockedAirship;
@property (nonatomic, strong) id mockedAnalytics;
@property (nonatomic, strong) id mockedPushDelegate;
@property (nonatomic, strong) id mockRegistrationDelegate;
@property (nonatomic, strong) id mockActionRunner;
@property (nonatomic, strong) id mockUAUtils;
@property (nonatomic, strong) id mockUAUser;
@property (nonatomic, strong) id mockUIUserNotificationSettings;
@property (nonatomic, strong) id mockDefaultNotificationCategories;
@property (nonatomic, strong) id mockTagGroupsAPIClient;
@property (nonatomic, strong) id mockProcessInfo;

@property (nonatomic, strong) id mockedUNNotification;

@property (nonatomic, strong) UAPush *push;
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;

@property (nonatomic, strong) NSDictionary *notification;
@property (nonatomic, strong) NSDictionary *emptyNotification;

@property (nonatomic, assign) NSUInteger testOSMajorVersion;


@end

@implementation UAPushTest

NSString *validDeviceToken = @"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";

void (^updateChannelTagsSuccessDoBlock)(NSInvocation *);
void (^updateChannelTagsFailureDoBlock)(NSInvocation *);

- (void)setUp {
    [super setUp];

    self.testOSMajorVersion = 8;
    self.mockProcessInfo = [OCMockObject niceMockForClass:[NSProcessInfo class]];
    [[[self.mockProcessInfo stub] andReturn:self.mockProcessInfo] processInfo];

    [[[[self.mockProcessInfo stub] andDo:^(NSInvocation *invocation) {
        NSOperatingSystemVersion arg;
        [invocation getArgument:&arg atIndex:2];

        BOOL result = self.testOSMajorVersion >= arg.majorVersion;
        [invocation setReturnValue:&result];
    }] ignoringNonObjectArgs] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){0, 0, 0}];

    self.dataStore = [UAPreferenceDataStore preferenceDataStoreWithKeyPrefix:@"uapush.test."];
    self.push =  [UAPush pushWithConfig:[UAConfig defaultConfig] dataStore:self.dataStore];

    self.notification = @{
                          @"aps": @{
                                  @"alert": @"sample alert!",
                                  @"badge": @2,
                                  @"sound": @"cat",
                                  @"category": @"notificationCategory"
                                  },
                          @"com.urbanairship.interactive_actions": @{
                                  @"backgroundIdentifier": @{
                                          @"backgroundAction": @"backgroundActionValue"
                                          },
                                  @"foregroundIdentifier": @{
                                          @"foregroundAction": @"foregroundActionValue",
                                          @"otherForegroundAction": @"otherForegroundActionValue"

                                          },
                                  },
                          @"someActionKey": @"someActionValue",
                          };

    self.emptyNotification = @{
                               @"aps": @{
                                       @"content-available": @1
                                       }
                               };

    // Mock the nested apple types with unavailable init methods
    self.mockedUNNotification = [OCMockObject niceMockForClass:[UNNotification class]];

    // Set up a mocked application
    self.mockedApplication = [OCMockObject niceMockForClass:[UIApplication class]];
    [[[self.mockedApplication stub] andReturn:self.mockedApplication] sharedApplication];

    // Set up mocked UIUserNotificationSettings
    self.mockUIUserNotificationSettings = [OCMockObject niceMockForClass:[UIUserNotificationSettings class]];

    // Set up a mocked device api client
    self.mockedChannelRegistrar = [OCMockObject niceMockForClass:[UAChannelRegistrar class]];
    self.push.channelRegistrar.delegate = nil;
    self.push.channelRegistrar = self.mockedChannelRegistrar;

    self.mockedAnalytics = [OCMockObject niceMockForClass:[UAAnalytics class]];

    self.mockedAirship =[OCMockObject niceMockForClass:[UAirship class]];
    [[[self.mockedAirship stub] andReturn:self.mockedAirship] shared];
    [[[self.mockedAirship stub] andReturn:self.mockedAnalytics] analytics];
    [[[self.mockedAirship stub] andReturn:self.dataStore] dataStore];

    self.mockedPushDelegate = [OCMockObject niceMockForProtocol:@protocol(UAPushNotificationDelegate)];
    self.push.pushNotificationDelegate = self.mockedPushDelegate;

    self.mockRegistrationDelegate = [OCMockObject niceMockForProtocol:@protocol(UARegistrationDelegate)];

    self.mockActionRunner = [OCMockObject mockForClass:[UAActionRunner class]];

    self.mockUAUtils = [OCMockObject niceMockForClass:[UAUtils class]];
    [[[self.mockUAUtils stub] andReturn:@"someDeviceID"] deviceID];

    self.mockUAUser = [OCMockObject niceMockForClass:[UAUser class]];
    [[[self.mockedAirship stub] andReturn:self.mockUAUser] inboxUser];
    [[[self.mockUAUser stub] andReturn:@"someUser"] username];

    self.mockDefaultNotificationCategories = [OCMockObject niceMockForClass:[UANotificationCategories class]];

    self.push.registrationDelegate = self.mockRegistrationDelegate;

    self.mockTagGroupsAPIClient = [OCMockObject niceMockForClass:[UATagGroupsAPIClient class]];
    self.push.tagGroupsAPIClient = self.mockTagGroupsAPIClient;
}

- (void)tearDown {
    self.push.pushNotificationDelegate = nil;
    self.push.registrationDelegate = nil;

    [self.dataStore removeAll];

    [self.mockedApplication stopMocking];
    [self.mockedChannelRegistrar stopMocking];
    [self.mockedAnalytics stopMocking];
    [self.mockedAirship stopMocking];
    [self.mockedPushDelegate stopMocking];
    [self.mockRegistrationDelegate stopMocking];
    [self.mockActionRunner stopMocking];
    [self.mockUAUtils stopMocking];
    [self.mockUAUser stopMocking];
    [self.mockUIUserNotificationSettings stopMocking];
    [self.mockDefaultNotificationCategories stopMocking];
    [self.mockTagGroupsAPIClient stopMocking];
    [self.mockProcessInfo stopMocking];

    [self.mockedUNNotification stopMocking];

    // We hide this class in a few tests. Its only available on iOS8.
    [UIUserNotificationSettings revealClass];

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
    XCTAssertTrue([self.dataStore boolForKey:UAPushBadgeSettingsKey],
                  @"autobadgeEnabled should be stored in standardUserDefaults");

    self.push.autobadgeEnabled = NO;
    XCTAssertFalse(self.push.autobadgeEnabled, @"autobadgeEnabled should be disabled when set to NO");
    XCTAssertFalse([self.dataStore boolForKey:UAPushBadgeSettingsKey],
                   @"autobadgeEnabled should be stored in standardUserDefaults");
}

- (void)testAlias {
    self.push.alias = @"some-alias";
    XCTAssertEqualObjects(@"some-alias", self.push.alias, @"alias is not being set correctly");
    XCTAssertEqualObjects(@"some-alias", [self.dataStore stringForKey:UAPushAliasSettingsKey],
                          @"alias should be stored in standardUserDefaults");

    self.push.alias = nil;
    XCTAssertNil(self.push.alias, @"alias should be able to be cleared");
    XCTAssertNil([self.dataStore stringForKey:UAPushAliasSettingsKey],
                 @"alias should be able to be cleared in standardUserDefaults");

    self.push.alias = @"";
    XCTAssertEqualObjects(@"", self.push.alias, @"alias is not being set correctly");
    XCTAssertEqualObjects(@"", [self.dataStore stringForKey:UAPushAliasSettingsKey],
                          @"alias should be stored in standardUserDefaults");

    self.push.alias = @"   ";
    XCTAssertEqualObjects(@"", self.push.alias, @"alias is not being trimmed and set correctly");
    XCTAssertEqualObjects(@"", [self.dataStore stringForKey:UAPushAliasSettingsKey],
                          @"alias should be stored in standardUserDefaults");

    self.push.alias = @"   a   ";
    XCTAssertEqualObjects(@"a", self.push.alias, @"alias is not being trimmed and set correctly");
    XCTAssertEqualObjects(@"a", [self.dataStore stringForKey:UAPushAliasSettingsKey],
                          @"alias should be stored in standardUserDefaults");
}

- (void)testTags {
    NSArray *tags = @[@"tag-one", @"tag-two"];
    self.push.tags = tags;

    XCTAssertEqual((NSUInteger)2, self.push.tags.count, @"should of added 2 tags");
    XCTAssertEqualObjects(tags, self.push.tags, @"tags are not stored correctly");
    XCTAssertEqualObjects([self.dataStore valueForKey:UAPushTagsSettingsKey], self.push.tags,
                          @"tags are not stored correctly in standardUserDefaults");

    self.push.tags = @[];
    XCTAssertEqual((NSUInteger)0, self.push.tags.count, @"tags should return an empty array even when set to nil");
    XCTAssertEqual((NSUInteger)0, [[self.dataStore valueForKey:UAPushTagsSettingsKey] count],
                   @"tags are not being cleared in standardUserDefaults");
}

/**
 * Tests tag setting when tag contains white space
 */
- (void)testSetTagsWhitespaceRemoval {
    NSArray *tags = @[@"   tag-one   ", @"tag-two   "];
    NSArray *tagsNoSpaces = @[@"tag-one", @"tag-two"];
    [self.push setTags:tags];

    XCTAssertEqualObjects(tagsNoSpaces, self.push.tags, @"whitespace was not trimmed from tags");
}

/**
 * Tests tag setting when tag consists entirely of whitespace
 */
- (void)testSetTagWhitespaceOnly {
    NSArray *tags = @[@" "];
    [self.push setTags:tags];

    XCTAssertNotEqualObjects(tags, self.push.tags, @"tag with whitespace only should not set");
}

/**
 * Tests tag setting when tag has minimum acceptable length
 */
- (void)testSetTagsMinTagSize {
    NSArray *tags = @[@"1"];
    [self.push setTags:tags];

    XCTAssertEqualObjects(tags, self.push.tags, @"tag with minimum character should set");
}

/**
 * Tests tag setting when tag has maximum acceptable length
 */
- (void)testSetTagsMaxTagSize {
    NSArray *tags = @[[@"" stringByPaddingToLength:127 withString: @"." startingAtIndex:0]];
    [self.push setTags:tags];

    XCTAssertEqualObjects(tags, self.push.tags, @"tag with maximum characters should set");
}

/**
 * Tests tag setting when tag has multi-byte characters
 */
- (void)testSetTagsMultiByteCharacters {
    NSArray *tags = @[@"함수 목록"];
    [self.push setTags:tags];

    XCTAssertEqualObjects(tags, self.push.tags, @"tag with multi-byte characters should set");
}

/**
 * Tests tag setting when tag has multi-byte characters and minimum length
 */
- (void)testMinLengthMultiByteCharacters {
    NSArray *tags = @[@"함"];
    [self.push setTags:tags];

    XCTAssertEqualObjects(tags, self.push.tags, @"tag with minimum multi-byte characters should set");
}

/**
 * Tests tag setting when tag has multi-byte characters and maximum length
 */
- (void)testMaxLengthMultiByteCharacters {
    NSArray *tags = @[[@"" stringByPaddingToLength:127 withString: @"함" startingAtIndex:0]];;
    [self.push setTags:tags];

    XCTAssertEqualObjects(tags, self.push.tags, @"tag with maximum multi-byte characters should set");
}

/**
 * Tests tag setting when tag has greater than maximum acceptable length
 */
- (void)testSetTagsOverMaxTagSizeRemoval {
    NSArray *tags = @[[@"" stringByPaddingToLength:128 withString: @"." startingAtIndex:0]];
    [self.push setTags:tags];

    XCTAssertNotEqualObjects(tags, self.push.tags, @"tag with 128 characters should not set");
}

- (void)testAddTags {
    self.push.tags = @[];

    [self.push addTags:@[@"tag-one", @"tag-two"]];
    XCTAssertEqualObjects([NSSet setWithArray:(@[@"tag-one", @"tag-two"])], [NSSet setWithArray:self.push.tags],
                          @"Add tags to current device fails when no existing tags exist");

    // Try to add same tags again
    [self.push addTags:@[@"tag-one", @"tag-two"]];
    XCTAssertEqual((NSUInteger)2, self.push.tags.count, @"Add tags should not add duplicate tags");


    // Try to add a new set of tags, with one of the tags being unique
    [self.push addTags:@[@"tag-one", @"tag-three"]];

    XCTAssertEqual((NSUInteger)3, self.push.tags.count,
                   @"Add tags should add unique tags even if some of them are duplicate");

    XCTAssertEqualObjects([NSSet setWithArray:(@[@"tag-one", @"tag-two", @"tag-three"])], [NSSet setWithArray:self.push.tags],
                          @"Add tags should add unique tags even if some of them are duplicate");

    // Try to add an nil set of tags
    XCTAssertNoThrow([self.push addTags:[NSArray array]],
                     @"Should not throw when adding an empty tag array");
}

- (void)testAddTag {
    self.push.tags = @[];

    [self.push addTag:@"tag-one"];
    XCTAssertEqualObjects((@[@"tag-one"]), self.push.tags,
                          @"Add tag to current device fails when no existing tags exist");

    // Try to add same tag again
    [self.push addTag:@"tag-one"];
    XCTAssertEqual((NSUInteger)1, self.push.tags.count, @"Add tag should not add duplicate tags");

    // Add a new tag
    [self.push addTag:@"tag-two"];
    XCTAssertEqualObjects((@[@"tag-one", @"tag-two"]), self.push.tags,
                          @"Adding another tag to tags fails");
}

- (void)testRemoveTag {
    self.push.tags = @[];
    XCTAssertNoThrow([self.push removeTag:@"some-tag"],
                     @"Should not throw when removing a tag when tags are empty");

    self.push.tags = @[@"some-tag", @"some-other-tag"];
    XCTAssertNoThrow([self.push removeTag:@"some-not-found-tag"],
                     @"Should not throw when removing a tag that does not exist");

    [self.push removeTag:@"some-tag"];
    XCTAssertEqualObjects((@[@"some-other-tag"]), self.push.tags,
                          @"Remove tag from device should actually remove the tag");
}

- (void)testRemoveTags {
    self.push.tags = @[];

    XCTAssertNoThrow([self.push removeTags:@[@"some-tag"]],
                     @"Should not throw when removing tags when current tags are empty");

    self.push.tags = @[@"some-tag", @"some-other-tag"];
    XCTAssertNoThrow([self.push removeTags:@[@"some-not-found-tag"]],
                     @"Should not throw when removing tags that do not exist");

    [self.push removeTags:@[@"some-tag"]];
    XCTAssertEqualObjects((@[@"some-other-tag"]), self.push.tags,
                          @"Remove tags from device should actually remove the tag");
}

/**
 * Test enabling userPushNotificationsEnabled on >= iOS8 saves its settings
 * to NSUserDefaults and updates apns registration.
 */
- (void)testUserPushNotificationsEnabledIOS8 {
    self.testOSMajorVersion = 8;
    self.push.userPushNotificationsEnabled = NO;

    NSMutableSet *expectedCategories = [NSMutableSet set];
    for (UANotificationCategory *category in self.push.combinedCategories) {
        [expectedCategories addObject:[category asUIUserNotificationCategory]];
    }

    NSUInteger expectedTypes = self.push.notificationOptions;

    [[self.mockedApplication expect] registerUserNotificationSettings:[OCMArg checkWithBlock:^BOOL(id obj) {
        UIUserNotificationSettings *settings = (UIUserNotificationSettings *)obj;
        return expectedTypes == settings.types && expectedCategories.count == settings.categories.count;
    }]];

    self.push.userPushNotificationsEnabled = YES;

    XCTAssertTrue(self.push.userPushNotificationsEnabled,
                  @"userPushNotificationsEnabled should be enabled when set to YES");

    XCTAssertTrue([self.dataStore boolForKey:UAUserPushNotificationsEnabledKey],
                  @"userPushNotificationsEnabled should be stored in standardUserDefaults");

    XCTAssertNoThrow([self.mockedApplication verify],
                     @"userPushNotificationsEnabled should register for remote notifications");
}

/**
 * Test requireSettingsAppToDisableUserNotifications defaults to YES on
 * iOS8+ and prevents userPushNotificationsEnabled from being disabled,
 * once its enabled.
 */
-(void)testRequireSettingsAppToDisableUserNotificationsIOS8 {
    // Defaults to YES
    XCTAssertTrue(self.push.requireSettingsAppToDisableUserNotifications);

    // Verify it can be disabled
    self.push.requireSettingsAppToDisableUserNotifications = NO;
    XCTAssertFalse(self.push.requireSettingsAppToDisableUserNotifications);

    // Set up push for user notifications
    self.push.userPushNotificationsEnabled = YES;
    self.push.deviceToken = validDeviceToken;
    self.push.shouldUpdateAPNSRegistration = NO;

    // Prevent disabling userPushNotificationsEnabled
    self.push.requireSettingsAppToDisableUserNotifications = YES;

    // Verify we don't try to register when attempting to disable userPushNotificationsEnabled
    [[self.mockedApplication reject] registerUserNotificationSettings:OCMOCK_ANY];

    self.push.userPushNotificationsEnabled = NO;

    // Should still be YES
    XCTAssertTrue(self.push.userPushNotificationsEnabled);

    // Verify we did not update user notification settings
    [self.mockedApplication verify];
}

/**
 * Test disabling userPushNotificationsEnabled on >= iOS8 saves its settings
 * to NSUserDefaults and updates registration.
 */
- (void)testUserPushNotificationsDisabledIOS8 {
    self.testOSMajorVersion = 8;
    self.push.userPushNotificationsEnabled = YES;
    self.push.deviceToken = validDeviceToken;
    self.push.shouldUpdateAPNSRegistration = NO;

    // Make sure we have previously registered types
    UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeBadge categories:nil];
    [[[self.mockedApplication stub] andReturn:settings] currentUserNotificationSettings];


    // Make sure push is set to YES
    XCTAssertTrue(self.push.userPushNotificationsEnabled, @"userPushNotificationsEnabled should default to YES");

    // Add a device token so we get a device api callback
    [[self.mockedChannelRegistrar expect] registerWithChannelID:OCMOCK_ANY
                                                channelLocation:OCMOCK_ANY
                                                    withPayload:OCMOCK_ANY
                                                     forcefully:NO];


    UIUserNotificationSettings *expected = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeNone
                                                                             categories:nil];

    [[self.mockedApplication expect] registerUserNotificationSettings:expected];
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    self.push.requireSettingsAppToDisableUserNotifications = NO;
    self.push.userPushNotificationsEnabled = NO;

    XCTAssertFalse(self.push.userPushNotificationsEnabled,
                   @"userPushNotificationsEnabled should be disabled when set to NO");

    XCTAssertFalse([self.dataStore boolForKey:UAUserPushNotificationsEnabledKey],
                   @"userPushNotificationsEnabled should be stored in standardUserDefaults");

    XCTAssertNoThrow([self.mockedApplication verify],
                     @"userPushNotificationsEnabled should unregister for remote notifications");
}

/**
 * Test enabling or disabling backgroundPushNotificationsEnabled saves its settings
 * to NSUserDefaults and triggers a channel registration update.
 */
- (void)testBackgroundPushNotificationsEnabled {
    self.push.userPushNotificationsEnabled = YES;
    self.push.backgroundPushNotificationsEnabled = NO;

    // Add a device token so we get a device api callback
    [[self.mockedChannelRegistrar expect] registerWithChannelID:OCMOCK_ANY
                                                channelLocation:OCMOCK_ANY
                                                    withPayload:OCMOCK_ANY
                                                     forcefully:NO];

    self.push.backgroundPushNotificationsEnabled = YES;

    XCTAssertTrue([self.dataStore boolForKey:UABackgroundPushNotificationsEnabledKey],
                  @"backgroundPushNotificationsEnabled should be stored in standardUserDefaults");

    self.push.backgroundPushNotificationsEnabled = NO;
    XCTAssertFalse([self.dataStore boolForKey:UABackgroundPushNotificationsEnabledKey],
                   @"backgroundPushNotificationsEnabled should be stored in standardUserDefaults");

}

/**
 * Test enabling or disabling pushTokenRegistrationEnabled saves its settings
 * to NSUserDefaults and triggers a channel registration update.
 */
- (void)testPushTokenRegistrationEnabled {
    self.push.pushTokenRegistrationEnabled = NO;

    // Add a device token so we get a device api callback
    [[self.mockedChannelRegistrar expect] registerWithChannelID:OCMOCK_ANY
                                                channelLocation:OCMOCK_ANY
                                                    withPayload:OCMOCK_ANY
                                                     forcefully:NO];

    self.push.pushTokenRegistrationEnabled = YES;

    XCTAssertTrue([self.dataStore boolForKey:UAPushTokenRegistrationEnabledKey],
                  @"pushTokenRegistrationEnabled should be stored in standardUserDefaults");

    self.push.pushTokenRegistrationEnabled = NO;
    XCTAssertFalse([self.dataStore boolForKey:UAPushTokenRegistrationEnabledKey],
                   @"pushTokenRegistrationEnabled should be stored in standardUserDefaults");
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


- (void)testTimeZone {
    self.push.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"EST"];

    XCTAssertEqualObjects([NSTimeZone timeZoneWithAbbreviation:@"EST"],
                          self.push.timeZone,
                          @"timezone is not being set correctly");

    XCTAssertEqualObjects([[NSTimeZone timeZoneWithAbbreviation:@"EST"] name],
                          [self.dataStore stringForKey:UAPushTimeZoneSettingsKey],
                          @"timezone should be stored in standardUserDefaults");

    // Clear the timezone from preferences
    [self.dataStore removeObjectForKey:UAPushTimeZoneSettingsKey];


    XCTAssertEqualObjects([self.push.defaultTimeZoneForQuietTime abbreviation],
                          [self.push.timeZone abbreviation],
                          @"Timezone should default to defaultTimeZoneForQuietTime");

    XCTAssertNil([self.dataStore stringForKey:UAPushTimeZoneSettingsKey],
                 @"timezone should be able to be cleared in standardUserDefaults");
}

/**
 * Test update apns registration when user notifications are enabled on >= iOS8.
 */
- (void)testUpdateAPNSRegistrationUserNotificationsEnabled {
    self.testOSMajorVersion = 8;
    self.push.userPushNotificationsEnabled = YES;
    self.push.shouldUpdateAPNSRegistration = YES;
    self.push.customCategories = [NSSet set];
    self.push.registrationDelegate = self.mockRegistrationDelegate;

    NSMutableSet *expectedCategories = [NSMutableSet set];
    for (UANotificationCategory *category in self.push.combinedCategories) {
        [expectedCategories addObject:[category asUIUserNotificationCategory]];
    }

    NSUInteger expectedTypes = self.push.notificationOptions;

    XCTestExpectation *delegateCalled = [self expectationWithDescription:@"Delegate called"];

    __block UANotificationOptions expectedOptions;

    [[[self.mockRegistrationDelegate stub] andReturnValue:OCMOCK_VALUE(YES)] respondsToSelector:@selector(registrationFinishedForAPNS:categories:)];

    [[self.mockedApplication expect] registerUserNotificationSettings:[OCMArg checkWithBlock:^BOOL(id obj) {
        UIUserNotificationSettings *settings = (UIUserNotificationSettings *)obj;
        expectedOptions = (UANotificationOptions)settings;
        return expectedTypes == settings.types && expectedCategories.count == settings.categories.count;
    }]];

    [[[self.mockRegistrationDelegate expect] andDo:^(NSInvocation *invocation) {
        [delegateCalled fulfill];
    }]  notificationRegistrationFinishedWithOptions:7 categories:[OCMArg checkWithBlock:^BOOL(id obj) {
        NSSet *categories = (NSSet *)obj;

        return (categories.count == expectedCategories.count);
    }]];

    [self.push updateAPNSRegistration];

    [self waitForExpectationsWithTimeout:10 handler:nil];

    XCTAssertNoThrow([self.mockedApplication verify]);
    XCTAssertNoThrow([self.mockRegistrationDelegate verify]);

    XCTAssertFalse(self.push.shouldUpdateAPNSRegistration, @"Updating APNS registration should set shouldUpdateAPNSRegistration to NO");
}

/**
 * Test setting authorized types to a new type results in a call to the registration delegate
 */
-(void)testSetAuthorizedTypesCallsRegistrationDelegate {

    UANotificationOptions expectedOptions = 2;

    XCTestExpectation *delegateCalled = [self expectationWithDescription:@"Delegate called"];

    [[[self.mockRegistrationDelegate expect] andDo:^(NSInvocation *invocation) {
        [delegateCalled fulfill];
    }]  notificationAuthorizedOptionsDidChange:expectedOptions];

    // set authorized types
    self.push.authorizedNotificationOptions = expectedOptions;

    [self waitForExpectationsWithTimeout:10 handler:nil];

    [self.mockRegistrationDelegate verify];
}

/**
 * Test setting requireAuthorizationForDefaultCategories requests the correct
 * defaults user notification categories.
 */
- (void)testRequireAuthorizationForDefaultCategories {
    // Clear the custom categories so we can check only UA categories in comibinedCategories.
    self.push.customCategories = [NSSet set];

    XCTAssertTrue(self.push.combinedCategories.count);

    self.push.requireAuthorizationForDefaultCategories = YES;
    for (UANotificationCategory *category in self.push.combinedCategories) {
        for (UANotificationAction *action in category.actions) {
            // Only check background actions
            if ((action.options & UNNotificationActionOptionForeground) == UANotificationOptionNone) {
                XCTAssertTrue((action.options & UNNotificationActionOptionAuthenticationRequired) > 0, @"Invalid options for action: %@", action.identifier);

            }
        }
    }

    self.push.requireAuthorizationForDefaultCategories = NO;
    for (UANotificationCategory *category in self.push.combinedCategories) {
        for (UANotificationAction *action in category.actions) {
            // Only check background actions
            if ((action.options & UNNotificationActionOptionForeground) == UANotificationOptionNone) {
                XCTAssertFalse((action.options & UNNotificationActionOptionAuthenticationRequired) > 0, @"Invalid options for action: %@", action.identifier);

            }
        }
    }
}

/**
 * Test the user notification categories used to register is the union between
 * the default categories and the custom categories.
 */
- (void)testNotificationCategories {
    self.push.userPushNotificationsEnabled = YES;

    UANotificationCategory *defaultCategory = [UANotificationCategory categoryWithIdentifier:@"defaultCategory" actions:@[]  intentIdentifiers:@[] options:UNNotificationCategoryOptionNone];
    UANotificationCategory *customCategory = [UANotificationCategory categoryWithIdentifier:@"customCategory" actions:@[]  intentIdentifiers:@[] options:UNNotificationCategoryOptionNone];
    UANotificationCategory *anotherCustomCategory = [UANotificationCategory categoryWithIdentifier:@"anotherCustomCategory" actions:@[] intentIdentifiers:@[] options:UNNotificationCategoryOptionNone];

    NSSet *defaultSet = [NSSet setWithArray:@[defaultCategory]];
    [[[self.mockDefaultNotificationCategories stub] andReturn:defaultSet] defaultCategoriesWithRequireAuth:self.push.requireAuthorizationForDefaultCategories];

    NSSet *customSet = [NSSet setWithArray:@[customCategory, anotherCustomCategory]];
    self.push.customCategories = customSet;

    NSSet *expectedSet = [NSSet setWithArray:@[defaultCategory, customCategory, anotherCustomCategory]];
    XCTAssertEqualObjects(self.push.combinedCategories, expectedSet);
}


/**
 * Test update apns registration when user notifications are disabled on >= iOS8.
 */
- (void)testUpdateAPNSRegistrationUserNotificationsDisabledIOS8 {
    self.testOSMajorVersion = 8;

    // Make sure we have previously registered types
    UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeBadge categories:nil];
    [[[self.mockedApplication stub] andReturn:settings] currentUserNotificationSettings];

    self.push.userPushNotificationsEnabled = NO;
    UIUserNotificationSettings *expected = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeNone
                                                                             categories:nil];

    [[self.mockedApplication expect] registerUserNotificationSettings:expected];
    [self.push updateAPNSRegistration];

    XCTAssertNoThrow([self.mockedApplication verify],
                     @"should register UIUserNotificationTypeNone types and nil categories");
}


/**
 * Test update apns does not register for 0 types if already is registered for none.
 */
- (void)testUpdateAPNSRegistrationPushAlreadyDisabledIOS8 {
    self.testOSMajorVersion = 8;

    // Make sure we have previously registered types
    UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeNone categories:nil];
    [[[self.mockedApplication stub] andReturn:settings] currentUserNotificationSettings];

    self.push.userPushNotificationsEnabled = NO;
    //[self.push updateAPNSRegistration];

    // Make sure we do not register for none, if we are
    // already registered for none or it will prompt the user.
    [[self.mockedApplication reject] registerUserNotificationSettings:OCMOCK_ANY];

    [self.push updateAPNSRegistration];

    XCTAssertNoThrow([self.mockedApplication verify],
                     @"should register UIUserNotificationTypeNone types and nil categories");
}

- (void)testSetBadgeNumberAutoBadgeEnabled {
    // Set the right values so we can check if a device api client call was made or not
    self.push.userPushNotificationsEnabled = YES;
    self.push.autobadgeEnabled = YES;
    self.push.deviceToken = validDeviceToken;

    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE((NSInteger)30)] applicationIconBadgeNumber];
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    [[self.mockedApplication expect] setApplicationIconBadgeNumber:15];
    [[self.mockedChannelRegistrar expect] registerWithChannelID:OCMOCK_ANY
                                                channelLocation:OCMOCK_ANY
                                                    withPayload:OCMOCK_ANY
                                                     forcefully:YES];

    [self.push setBadgeNumber:15];
    XCTAssertNoThrow([self.mockedApplication verify],
                     @"should update application icon badge number when its different");

    XCTAssertNoThrow([self.mockedChannelRegistrar verify],
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
    self.push.userPushNotificationsEnabled = YES;
    self.push.deviceToken = validDeviceToken;

    self.push.autobadgeEnabled = NO;

    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE((NSInteger)30)] applicationIconBadgeNumber];
    [[self.mockedApplication expect] setApplicationIconBadgeNumber:15];

    // Reject device api client registration because autobadge is not enabled
    [[self.mockedChannelRegistrar reject] registerWithChannelID:OCMOCK_ANY
                                                channelLocation:OCMOCK_ANY
                                                    withPayload:OCMOCK_ANY
                                                     forcefully:YES];
    [self.push setBadgeNumber:15];
    XCTAssertNoThrow([self.mockedApplication verify],
                     @"should update application icon badge number when its different");

    XCTAssertNoThrow([self.mockedChannelRegistrar verify],
                     @"should not update registration because autobadge is disabled");
}

/**
 * Test quietTimeEnabled.
 */
- (void)testSetQuietTimeEnabled {
    [self.dataStore removeObjectForKey:UAPushQuietTimeEnabledSettingsKey];
    XCTAssertFalse(self.push.quietTimeEnabled, @"QuietTime should be disabled");

    self.push.quietTimeEnabled = YES;
    XCTAssertTrue(self.push.quietTimeEnabled, @"QuietTime should be enabled");

    self.push.quietTimeEnabled = NO;
    XCTAssertFalse(self.push.quietTimeEnabled, @"QuietTime should be disabled");
}

/**
 * Test setting the default userPushNotificationsEnabled value.
 */
- (void)testUserPushNotificationsEnabledByDefault {
    self.push.userPushNotificationsEnabledByDefault = YES;
    XCTAssertTrue(self.push.userPushNotificationsEnabled, @"default user notification value not taking affect.");

    self.push.userPushNotificationsEnabledByDefault = NO;
    XCTAssertFalse(self.push.userPushNotificationsEnabled, @"default user notification value not taking affect.");
}

/**
 * Test setting the default backgroundPushNotificationEnabled value.
 */
- (void)testBackgroundPushNotificationsEnabledByDefault {
    self.push.backgroundPushNotificationsEnabledByDefault = YES;
    XCTAssertTrue(self.push.backgroundPushNotificationsEnabled, @"default background notification value not taking affect.");

    self.push.backgroundPushNotificationsEnabledByDefault = NO;
    XCTAssertFalse(self.push.backgroundPushNotificationsEnabled, @"default background notification value not taking affect.");
}

/**
 * Test update registration when shouldUpdateAPNSRegistration is true, updates
 * apns registration and not channel registration.
 */
- (void)testUpdateRegistrationShouldUpdateAPNS {
    self.push.shouldUpdateAPNSRegistration = YES;

    // Reject any device registration
    [[self.mockedChannelRegistrar reject] registerWithChannelID:OCMOCK_ANY
                                                channelLocation:OCMOCK_ANY
                                                    withPayload:OCMOCK_ANY
                                                     forcefully:NO];

    // Update the registration
    [self.push updateRegistration];

    // Verify it reset the flag
    XCTAssertFalse(self.push.shouldUpdateAPNSRegistration, @"updateRegistration should handle APNS registration updates if shouldUpdateAPNSRegistration is YES.");
}

/**
 * Tests update registration when channel creation flag is disabled.
 */
- (void)testChannelCreationFlagDisabled {

    // Prevent beginRegistrationBackgroundTask early return
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    // Test when channel creation is disabled
    self.push.channelCreationEnabled = NO;
    [[self.mockedChannelRegistrar reject] registerWithChannelID:OCMOCK_ANY channelLocation:OCMOCK_ANY withPayload:OCMOCK_ANY forcefully:NO];

    [self.push updateChannelRegistrationForcefully:NO];

    [self.mockedChannelRegistrar verify];
}

/**
 * Tests update registration when channel creation flag is enabled.
 */
- (void)testChannelCreationFlagEnabled {

    // Prevent beginRegistrationBackgroundTask early return
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    // Test when channel creation is enabled
    self.push.channelCreationEnabled = YES;
    [[self.mockedChannelRegistrar expect] registerWithChannelID:OCMOCK_ANY channelLocation:OCMOCK_ANY withPayload:OCMOCK_ANY forcefully:NO];

    [self.push updateChannelRegistrationForcefully:NO];

    [self.mockedChannelRegistrar verify];
}

/**
 * Tests enabling channel delay after channel ID has been registered.
 */
- (void)testEnableChannelDelayWithChannelID {

    // Set channelCreationDelayEnabled to NO
    UAConfig *config = [UAConfig defaultConfig];
    config.channelCreationDelayEnabled = NO;

    // Init push
    self.push =  [UAPush pushWithConfig:config dataStore:self.dataStore];

    // Ensure channel creation enabled is YES
    XCTAssertTrue(self.push.channelCreationEnabled);

    // Set channelCreationDelayEnabled to YES
    config = [UAConfig defaultConfig];
    config.channelCreationDelayEnabled = YES;

    // Init push
    self.push =  [UAPush pushWithConfig:config dataStore:self.dataStore];

    // Ensure channel creation enabled is NO
    XCTAssertFalse(self.push.channelCreationEnabled);

    // Mock the datastore to populate a mock channel location and channel id in UAPush init
    id mockDataStore = [OCMockObject niceMockForClass:[UAPreferenceDataStore class]];
    [[[mockDataStore stub] andReturn:@"someChannelLocation"] stringForKey:UAPushChannelLocationKey];
    [[[mockDataStore stub] andReturn:@"someChannelID"] stringForKey:UAPushChannelIDKey];

    self.push =  [UAPush pushWithConfig:config dataStore:mockDataStore];

    // Ensure channel creation enabled is YES
    XCTAssertTrue(self.push.channelCreationEnabled);
}

- (void)testUpdateRegistrationForcefullyPushEnabled {
    self.push.userPushNotificationsEnabled = YES;
    self.push.deviceToken = validDeviceToken;

    // Check every app state.  We want to allow manual registration in any state.
    for(int i = UIApplicationStateActive; i < UIApplicationStateBackground; i++) {
        UIApplicationState state = (UIApplicationState)i;
        self.push.registrationBackgroundTask = UIBackgroundTaskInvalid;

        [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(state)] applicationState];

        [[self.mockedChannelRegistrar expect] registerWithChannelID:OCMOCK_ANY
                                                    channelLocation:OCMOCK_ANY
                                                        withPayload:OCMOCK_ANY
                                                         forcefully:YES];

        [[[self.mockedApplication expect] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

        [self.push updateChannelRegistrationForcefully:YES];
        XCTAssertNoThrow([self.mockedChannelRegistrar verify],
                         @"updateRegistration should register with the channel registrar if push is enabled.");

        XCTAssertNoThrow([self.mockedApplication verify], @"A background task should be requested for every update");
    }
}


- (void)testUpdateRegistrationForcefullyPushDisabled {
    self.push.userPushNotificationsEnabled = NO;
    self.push.deviceToken = validDeviceToken;

    // Add a device token so we get a device api callback
    [[self.mockedChannelRegistrar expect] registerWithChannelID:OCMOCK_ANY
                                                channelLocation:OCMOCK_ANY
                                                    withPayload:OCMOCK_ANY
                                                     forcefully:YES];


    [[[self.mockedApplication expect] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];


    [self.push updateChannelRegistrationForcefully:YES];
    XCTAssertNoThrow([self.mockedChannelRegistrar verify],
                     @"updateRegistration should unregister with the channel registrar if push is disabled.");

    XCTAssertNoThrow([self.mockedApplication verify], @"A background task should be requested for every update");
}

- (void)testUpdateRegistrationInvalidBackgroundTask {
    self.push.userPushNotificationsEnabled = YES;
    self.push.deviceToken = validDeviceToken;

    [[[self.mockedApplication expect] andReturnValue:OCMOCK_VALUE((NSUInteger)UIBackgroundTaskInvalid)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    [[self.mockedChannelRegistrar reject] registerWithChannelID:OCMOCK_ANY
                                                channelLocation:OCMOCK_ANY
                                                    withPayload:OCMOCK_ANY
                                                     forcefully:YES];

    [self.push updateChannelRegistrationForcefully:YES];


    XCTAssertNoThrow([self.mockedChannelRegistrar verify],
                     @"updateRegistration should not call any registration without a valid background task");
}

- (void)testUpdateRegistrationExistingBackgroundTask {
    self.push.registrationBackgroundTask = 30;
    [[self.mockedApplication reject] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    [self.push updateChannelRegistrationForcefully:YES];

    XCTAssertNoThrow([self.mockedApplication verify], @"A background task should not be requested if one already exists");
}

/**
 * Test registration payload when pushTokenRegistrationEnabled is NO does not include device token
 */
- (void)testRegistrationPayloadPushTokenRegistrationEnabledNo {
    [UIUserNotificationSettings hideClass];

    // Set up UAPush to give a full, opted in payload
    self.push.pushTokenRegistrationEnabled = NO;
    self.push.deviceToken = validDeviceToken;
    self.push.alias = @"ALIAS";
    self.push.channelTagRegistrationEnabled = YES;
    self.push.tags = @[@"tag-one"];
    self.push.autobadgeEnabled = NO;
    self.push.quietTimeEnabled = YES;
    self.push.timeZone = [NSTimeZone timeZoneWithName:@"Pacific/Auckland"];
    [self.push setQuietTimeStartHour:12 startMinute:0 endHour:12 endMinute:0];

    // Opt in requirements
    self.push.userPushNotificationsEnabled = YES;
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIRemoteNotificationTypeAlert)] enabledRemoteNotificationTypes];

    BOOL (^checkPayloadBlock)(id obj) = ^BOOL(id obj) {
        UAChannelRegistrationPayload *payload = (UAChannelRegistrationPayload *)obj;
        return payload.pushAddress == nil;
    };

    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];
    [[self.mockedChannelRegistrar expect] registerWithChannelID:OCMOCK_ANY
                                                channelLocation:OCMOCK_ANY
                                                    withPayload:[OCMArg checkWithBlock:checkPayloadBlock]
                                                     forcefully:YES];

    [self.push updateChannelRegistrationForcefully:YES];

    XCTAssertNoThrow([self.mockedChannelRegistrar verify],
                     @"payload is not being created with expected values");
}

/**
 * Test when backgroundPushNotificationsAllowed is YES when running >= iOS8,
 * device token is available, remote-notification background mode is enabled,
 * backgroundRefreshStatus is allowed, backgroundPushNotificationsEnabled is
 * enabled and pushTokenRegistrationEnabled is YES.
 */
- (void)testBackgroundPushNotificationsAllowedIOS8 {
    self.push.deviceToken = validDeviceToken;
    self.push.backgroundPushNotificationsEnabled = YES;
    self.push.pushTokenRegistrationEnabled = YES;
    [[[self.mockedAirship stub] andReturnValue:OCMOCK_VALUE(YES)] remoteNotificationBackgroundModeEnabled];
    [[[self.mockedApplication stub] andReturnValue:@(UIBackgroundRefreshStatusAvailable)] backgroundRefreshStatus];
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(YES)] isRegisteredForRemoteNotifications];

    XCTAssertTrue(self.push.backgroundPushNotificationsAllowed,
                  @"BackgroundPushNotificationsAllowed should be YES");
}

/**
 * Test when backgroundPushNotificationsAllowed is NO when the device token is
 * missing.
 */
- (void)testBackgroundPushNotificationsDisallowedNoDeviceToken {
    self.push.userPushNotificationsEnabled = YES;
    self.push.backgroundPushNotificationsEnabled = YES;
    [[[self.mockedAirship stub] andReturnValue:OCMOCK_VALUE(YES)] remoteNotificationBackgroundModeEnabled];
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(YES)] isRegisteredForRemoteNotifications];
    [[[self.mockedApplication stub] andReturnValue:@(UIBackgroundRefreshStatusAvailable)] backgroundRefreshStatus];

    self.push.deviceToken = nil;
    XCTAssertFalse(self.push.backgroundPushNotificationsAllowed,
                   @"BackgroundPushNotificationsAllowed should be NO");
}

/**
 * Test when backgroundPushNotificationsAllowed is NO when backgroundPushNotificationsAllowed
 * is disabled.
 */
- (void)testBackgroundPushNotificationsDisallowedDisabled {
    self.push.userPushNotificationsEnabled = YES;
    [[[self.mockedAirship stub] andReturnValue:OCMOCK_VALUE(YES)] remoteNotificationBackgroundModeEnabled];
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(YES)] isRegisteredForRemoteNotifications];
    [[[self.mockedApplication stub] andReturnValue:@(UIBackgroundRefreshStatusAvailable)] backgroundRefreshStatus];
    self.push.deviceToken = validDeviceToken;


    self.push.backgroundPushNotificationsEnabled = NO;
    XCTAssertFalse(self.push.backgroundPushNotificationsAllowed,
                   @"BackgroundPushNotificationsAllowed should be NO");
}

/**
 * Test when backgroundPushNotificationsAllowed is NO when the application is not
 * configured with remote-notification background mode.
 */
- (void)testBackgroundPushNotificationsDisallowedBackgroundNotificationDisabled {
    self.push.userPushNotificationsEnabled = YES;
    self.push.backgroundPushNotificationsEnabled = YES;
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(YES)] isRegisteredForRemoteNotifications];
    [[[self.mockedApplication stub] andReturnValue:@(UIBackgroundRefreshStatusAvailable)] backgroundRefreshStatus];
    self.push.deviceToken = validDeviceToken;

    [[[self.mockedAirship stub] andReturnValue:OCMOCK_VALUE(NO)] remoteNotificationBackgroundModeEnabled];
    XCTAssertFalse(self.push.backgroundPushNotificationsAllowed,
                   @"BackgroundPushNotificationsAllowed should be NO");
}

/**
 * Test when backgroundPushNotificationsAllowed is NO when backgroundRefreshStatus is invalid.
 */
- (void)testBackgroundPushNotificationsDisallowedInvalidBackgroundRefreshStatus {
    self.push.userPushNotificationsEnabled = YES;
    self.push.backgroundPushNotificationsEnabled = YES;
    [[[self.mockedAirship stub] andReturnValue:OCMOCK_VALUE(YES)] remoteNotificationBackgroundModeEnabled];
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(YES)] isRegisteredForRemoteNotifications];
    self.push.deviceToken = validDeviceToken;

    [[[self.mockedApplication stub] andReturnValue:@(UIBackgroundRefreshStatusRestricted)] backgroundRefreshStatus];

    XCTAssertFalse(self.push.backgroundPushNotificationsAllowed,
                   @"BackgroundPushNotificationsAllowed should be NO");
}

/**
 * Test that backgroundPushNotificationsAllowed is NO when not registered for remote notifications.
 */
- (void)testBackgroundPushNotificationsDisallowedNotRegisteredForRemoteNotificationsIOS8 {
    self.push.backgroundPushNotificationsEnabled = YES;
    [[[self.mockedApplication stub] andReturnValue:@(UIBackgroundRefreshStatusAvailable)] backgroundRefreshStatus];
    [[[self.mockedAirship stub] andReturnValue:OCMOCK_VALUE(YES)] remoteNotificationBackgroundModeEnabled];
    self.push.deviceToken = validDeviceToken;

    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(NO)] isRegisteredForRemoteNotifications];
    XCTAssertFalse(self.push.backgroundPushNotificationsAllowed,
                   @"BackgroundPushNotificationsAllowed should be NO");
}

/**
 * Test when backgroundPushNotificationsAllowed is NO when
 * pushTokenRegistrationEnabled is NO.
 */
- (void)testBackgroundPushNotificationsPushTokenRegistrationEnabledNo {
    self.push.deviceToken = validDeviceToken;
    self.push.backgroundPushNotificationsEnabled = YES;
    self.push.pushTokenRegistrationEnabled = NO;
    [[[self.mockedAirship stub] andReturnValue:OCMOCK_VALUE(YES)] remoteNotificationBackgroundModeEnabled];
    [[[self.mockedApplication stub] andReturnValue:@(UIBackgroundRefreshStatusAvailable)] backgroundRefreshStatus];
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(YES)] isRegisteredForRemoteNotifications];

    XCTAssertFalse(self.push.backgroundPushNotificationsAllowed,
                   @"BackgroundPushNotificationsAllowed should be NO");
}

/**
 * Test that UserPushNotificationAllowed is YES when there are authorized notification types set
 */
-(void)testUserPushNotificationsAllowedIOS8 {
    self.testOSMajorVersion = 8;

    self.push.userPushNotificationsEnabled = YES;
    self.push.pushTokenRegistrationEnabled = YES;
    self.push.deviceToken = validDeviceToken;
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(YES)] isRegisteredForRemoteNotifications];

    UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeBadge categories:nil];
    [[[self.mockedApplication stub] andReturn:settings] currentUserNotificationSettings];

    [self.push updateAPNSRegistration];

    XCTAssertTrue(self.push.userPushNotificationsAllowed,
                  @"UserPushNotificationsAllowed should be YES");
}

/**
 * Test that UserPushNotificationAllowed is NO when there are no authorized notification types set
 */
-(void)testUserPushNotificationsAllowedIOS8No {
    self.testOSMajorVersion = 8;

    self.push.userPushNotificationsEnabled = YES;
    self.push.pushTokenRegistrationEnabled = NO;
    self.push.deviceToken = validDeviceToken;
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(YES)] isRegisteredForRemoteNotifications];

    XCTAssertFalse(self.push.userPushNotificationsAllowed,
                  @"UserPushNotificationsAllowed should be NO");
}

/**
 * Test that UserPushNotificationAllowed is NO
 */
- (void)testRegistrationPayloadNoDeviceToken {
    // Set up UAPush to give minimum payload
    self.push.deviceToken = nil;
    self.push.alias = nil;
    self.push.channelTagRegistrationEnabled = NO;
    self.push.autobadgeEnabled = NO;
    self.push.quietTimeEnabled = NO;

    // Opt in requirements
    self.push.userPushNotificationsEnabled = YES;
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
    [[self.mockedChannelRegistrar expect] registerWithChannelID:OCMOCK_ANY channelLocation:OCMOCK_ANY withPayload:[OCMArg checkWithBlock:checkPayloadBlock] forcefully:YES];

    [self.push updateChannelRegistrationForcefully:YES];

    XCTAssertNoThrow([self.mockedChannelRegistrar verify],
                     @"payload is not being created with expected values");

}

- (void)testRegistrationPayloadDeviceTagsDisabled {
    self.push.userPushNotificationsEnabled = YES;
    self.push.channelTagRegistrationEnabled = NO;
    self.push.tags = @[@"tag-one"];

    // Check that the payload setTags is NO and the tags is nil
    BOOL (^checkPayloadBlock)(id obj) = ^(id obj) {
        UAChannelRegistrationPayload *payload = obj;
        return (BOOL)(!payload.setTags && payload.tags == nil);
    };

    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];
    [[self.mockedChannelRegistrar expect] registerWithChannelID:OCMOCK_ANY
                                                channelLocation:OCMOCK_ANY
                                                    withPayload:[OCMArg checkWithBlock:checkPayloadBlock]
                                                     forcefully:YES];

    [self.push updateChannelRegistrationForcefully:YES];

    XCTAssertNoThrow([self.mockedChannelRegistrar verify],
                     @"payload is including tags when device tags is NO");

}

- (void)testRegistrationPayloadAutoBadgeEnabled {
    self.push.userPushNotificationsEnabled = YES;
    self.push.autobadgeEnabled = YES;
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE((NSInteger)30)] applicationIconBadgeNumber];

    // Check that the payload setTags is NO and the tags is nil
    BOOL (^checkPayloadBlock)(id obj) = ^(id obj) {
        UAChannelRegistrationPayload *payload = obj;
        return (BOOL)([payload.badge integerValue] == 30);
    };

    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];
    [[self.mockedChannelRegistrar expect] registerWithChannelID:OCMOCK_ANY
                                                channelLocation:OCMOCK_ANY
                                                    withPayload:[OCMArg checkWithBlock:checkPayloadBlock]
                                                     forcefully:YES];

    [self.push updateChannelRegistrationForcefully:YES];

    XCTAssertNoThrow([self.mockedChannelRegistrar verify],
                     @"payload is not including the correct badge when auto badge is enabled");
}

- (void)testRegistrationPayloadNoQuietTime {
    self.push.userPushNotificationsEnabled = YES;
    self.push.quietTimeEnabled = NO;


    // Check that the payload does not include a quiet time
    BOOL (^checkPayloadBlock)(id obj) = ^(id obj) {
        UAChannelRegistrationPayload *payload = obj;
        return (BOOL)(payload.quietTime == nil);
    };

    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];
    [[self.mockedChannelRegistrar expect] registerWithChannelID:OCMOCK_ANY
                                                channelLocation:OCMOCK_ANY
                                                    withPayload:[OCMArg checkWithBlock:checkPayloadBlock]
                                                     forcefully:YES];

    [self.push updateChannelRegistrationForcefully:YES];

    XCTAssertNoThrow([self.mockedChannelRegistrar verify],
                     @"payload should not include quiet time if quiet time is disabled");
}


/**
 * Test applicationDidEnterBackground clears the notification and sets
 * the hasEnteredBackground flag
 */
- (void)testApplicationDidEnterBackground {
    self.push.launchNotificationResponse = [[UANotificationResponse alloc] init];

    [self.push applicationDidEnterBackground];
    XCTAssertNil(self.push.launchNotificationResponse, @"applicationDidEnterBackground should clear the launch notification");
    XCTAssertTrue([self.dataStore boolForKey:UAPushChannelCreationOnForeground], @"applicationDidEnterBackground should set channelCreationOnForeground to true");
}

/**
 * Test update registration is called when the device enters a background and
 * we do not have a channel ID
 */
- (void)testApplicationDidEnterBackgroundCreatesChannel {
    self.push.channelID = nil;
    self.push.userPushNotificationsEnabled = YES;

    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    [[self.mockedChannelRegistrar expect] registerWithChannelID:OCMOCK_ANY
                                                channelLocation:OCMOCK_ANY
                                                    withPayload:OCMOCK_ANY
                                                     forcefully:NO];

    [self.push applicationDidEnterBackground];

    XCTAssertNoThrow([self.mockedChannelRegistrar verify], @"Channel registration should be called");
}

/**
 * Test channel created
 */
- (void)testChannelCreated {
    [self.push channelCreated:@"someChannelID" channelLocation:@"someLocation" existing:YES];

    XCTAssertEqualObjects(self.push.channelID, @"someChannelID", @"The channel ID should be set on channel creation.");
    XCTAssertEqualObjects(self.push.channelLocation, @"someLocation", @"The channel location should be set on channel creation.");
}

/**
 * Test existing channel created posts an NSNotification
 */
- (void)testExistingChannelCreatedNSNotification {

    id expectedUserInfo = @{ UAChannelCreatedEventExistingKey: @(YES),
                             UAChannelCreatedEventChannelKey:@"someChannelID" };

    XCTestExpectation *notificationFired = [self expectationWithDescription:@"Notification event fired"];

    id testObserver = [[UATestNotificationObserver alloc] initWithBlock:^(NSNotification *notification) {
        XCTAssertEqualObjects(expectedUserInfo, notification.userInfo);
        [notificationFired fulfill];
    }];

    [[NSNotificationCenter defaultCenter] addObserver:testObserver selector:@selector(handleNotification:) name:UAChannelCreatedEvent object:self.push];

    [self.push channelCreated:@"someChannelID" channelLocation:@"someLocation" existing:YES];

    [self waitForExpectationsWithTimeout:10 handler:nil];

    [[NSNotificationCenter defaultCenter] removeObserver:testObserver];
}

/**
 * Test new channel created posts an NSNotification
 */
- (void)testNewChannelCreatedNSNotification {

    id expectedUserInfo = @{ UAChannelCreatedEventExistingKey: @(NO),
                             UAChannelCreatedEventChannelKey:@"someChannelID" };

    XCTestExpectation *notificationFired = [self expectationWithDescription:@"Notification event fired"];

    id testObserver = [[UATestNotificationObserver alloc] initWithBlock:^(NSNotification *notification) {
        XCTAssertEqualObjects(expectedUserInfo, notification.userInfo);
        [notificationFired fulfill];
    }];

    [[NSNotificationCenter defaultCenter] addObserver:testObserver selector:@selector(handleNotification:) name:UAChannelCreatedEvent object:self.push];

    [self.push channelCreated:@"someChannelID" channelLocation:@"someLocation" existing:NO];

    [self waitForExpectationsWithTimeout:10 handler:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:testObserver];
}

/**
 * Test registration succeeded with channels and an up to date payload
 */
- (void)testRegistrationSucceeded {
    self.push.deviceToken = validDeviceToken;
    self.push.channelID = @"someChannelID";
    self.push.channelLocation = @"someChannelLocation";
    self.push.registrationBackgroundTask = 30;

    XCTestExpectation *delegateCalled = [self expectationWithDescription:@"Delegate called"];

    [[[self.mockRegistrationDelegate expect] andDo:^(NSInvocation *invocation) {
        [delegateCalled fulfill];
    }] registrationSucceededForChannelID:@"someChannelID" deviceToken:validDeviceToken];

    [[self.mockedApplication expect] endBackgroundTask:30];

    [self.push registrationSucceededWithPayload:[self.push createChannelPayload]];

    [self waitForExpectationsWithTimeout:10 handler:nil];
    XCTAssertNoThrow([self.mockRegistrationDelegate verify], @"Delegate should be called");
    XCTAssertNoThrow([self.mockedApplication verify], @"Should end the background task");
}

/**
 * Test registration succeeded with an out of date payload
 */
- (void)testRegistrationSucceededUpdateNeeded {
    self.push.deviceToken = validDeviceToken;
    self.push.channelID = @"someChannelID";
    self.push.channelLocation = @"someChannelLocation";
    self.push.registrationBackgroundTask = 30;

    XCTestExpectation *delegateCalled = [self expectationWithDescription:@"Delegate called"];

    [[[self.mockRegistrationDelegate expect] andDo:^(NSInvocation *invocation) {
        [delegateCalled fulfill];
    }]  registrationSucceededForChannelID:@"someChannelID" deviceToken:validDeviceToken];

    [[self.mockedChannelRegistrar expect] registerWithChannelID:OCMOCK_ANY
                                                channelLocation:OCMOCK_ANY
                                                    withPayload:OCMOCK_ANY
                                                     forcefully:NO];

    // Should not end the background task
    [[self.mockedApplication reject] endBackgroundTask:30];

    // Call with an empty payload.  Should be different then the UAPush generated payload
    [self.push registrationSucceededWithPayload:[[UAChannelRegistrationPayload alloc] init]];

    [self waitForExpectationsWithTimeout:10 handler:nil];

    XCTAssertNoThrow([self.mockRegistrationDelegate verify], @"Delegate should be called");
    XCTAssertNoThrow([self.mockedApplication verify], @"Should not end the background task");
}


/**
 * Test registration failed
 */
- (void)testRegistrationFailed {
    self.push.registrationBackgroundTask = 30;

    XCTestExpectation *delegateCalled = [self expectationWithDescription:@"Delegate called"];

    [[[self.mockRegistrationDelegate expect] andDo:^(NSInvocation *invocation) {
        [delegateCalled fulfill];
    }] registrationFailed];

    [[self.mockedApplication expect] endBackgroundTask:30];

    [self.push registrationFailedWithPayload:[[UAChannelRegistrationPayload alloc] init]];
    [self waitForExpectationsWithTimeout:10 handler:nil];

    XCTAssertNoThrow([self.mockRegistrationDelegate verify], @"Delegate should be called");
    XCTAssertNoThrow([self.mockedApplication verify], @"Should end the background task");
}

/**
 * Test setting the channel ID generates the device registration event with the
 * channel ID.
 */
- (void)testSetChannelID {
    self.push.channelID = @"someChannelID";
    self.push.channelLocation = @"someChannelLocation";

    XCTAssertEqualObjects(@"someChannelID", self.push.channelID, @"Channel ID is not being set properly");
}

/**
 * Test setting the channel ID without a channel location returns nil.
 */
- (void)testSetChannelIDNoLocation {
    self.push.channelID = @"someChannelID";
    self.push.channelLocation = nil;

    XCTAssertNil(self.push.channelID, @"Channel ID should be nil without location.");
}

/**
 * Test migrating the userNotificationEnabled key no ops when its already set on
 * >= iOS8.
 */
- (void)testMigrateNewRegistrationFlowAlreadySetIOS8 {
    // Set the UAUserPushNotificationsEnabledKey setting to NO
    [self.dataStore setBool:NO forKey:UAUserPushNotificationsEnabledKey];


    UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert categories:nil];
    [[[self.mockedApplication stub] andReturn:settings] currentUserNotificationSettings];

    // Force a migration
    [self.dataStore removeObjectForKey:UAPushEnabledSettingsMigratedKey];
    [self.push migratePushSettings];

    // Verify its still NO
    XCTAssertFalse([self.dataStore boolForKey:UAUserPushNotificationsEnabledKey]);
}
/**
 * Test migrating the userNotificationEnabled key does not set if the
 * current notification types is none on >= iOS8.
 */
- (void)testMigrateNewRegistrationFlowDisabledIOS8 {
    // Clear the UAUserPushNotificationsEnabledKey setting
    [self.dataStore removeObjectForKey:UAUserPushNotificationsEnabledKey];
    [self.dataStore removeObjectForKey:UAPushEnabledSettingsMigratedKey];

    UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeNone categories:nil];
    [[[self.mockedApplication stub] andReturn:settings] currentUserNotificationSettings];

    [self.push migratePushSettings];

    // Verify it was not set
    XCTAssertNil([self.dataStore objectForKey:UAUserPushNotificationsEnabledKey]);
}

/**
 * Test migrating the userNotificationEnabled key does set to YES if the
 * current notification types is not none on >= iOS8.
 */
- (void)testMigrateNewRegistrationFlowEnabledIOS8 {
    // Clear the UAUserPushNotificationsEnabledKey setting
    [self.dataStore removeObjectForKey:UAUserPushNotificationsEnabledKey];
    [self.dataStore removeObjectForKey:UAPushEnabledSettingsMigratedKey];

    UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert categories:nil];
    [[[self.mockedApplication stub] andReturn:settings] currentUserNotificationSettings];

    [self.push migratePushSettings];

    // Verify it was set to YES
    XCTAssertTrue([self.dataStore boolForKey:UAUserPushNotificationsEnabledKey]);
}

/**
 * Test migrating only performs once.
 */
- (void)testMigrateNewRegistrationFlowOnlyOnce {
    // Clear the UAUserPushNotificationsEnabledKey setting
    [self.dataStore removeObjectForKey:UAUserPushNotificationsEnabledKey];
    [self.dataStore removeObjectForKey:UAPushEnabledSettingsMigratedKey];

    UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert categories:nil];
    [[[self.mockedApplication stub] andReturn:settings] currentUserNotificationSettings];

    [self.push migratePushSettings];

    // Verify it was set to YES
    XCTAssertTrue([self.dataStore boolForKey:UAUserPushNotificationsEnabledKey]);
    XCTAssertTrue([self.dataStore boolForKey:UAPushEnabledSettingsMigratedKey]);

    // Clear the UAUserPushNotificationsEnabledKey setting
    [self.dataStore removeObjectForKey:UAUserPushNotificationsEnabledKey];

    [self.push migratePushSettings];

    // Should not enable it the second time
    XCTAssertFalse([self.dataStore boolForKey:UAUserPushNotificationsEnabledKey]);
}

/**
 * Test when allowUnregisteringUserNotificationTypes is NO it prevents UAPush from
 * unregistering user notification types.
 */
- (void)testDisallowUnregisteringUserNotificationTypes {
    self.testOSMajorVersion = 8;
    self.push.userPushNotificationsEnabled = YES;
    self.push.deviceToken = validDeviceToken;
    self.push.shouldUpdateAPNSRegistration = NO;
    self.push.requireSettingsAppToDisableUserNotifications = NO;

    // Turn off allowing unregistering user notification types
    self.push.allowUnregisteringUserNotificationTypes = NO;

    // Make sure we have previously registered types
    UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeBadge categories:nil];
    [[[self.mockedApplication stub] andReturn:settings] currentUserNotificationSettings];

    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    // Add a device token so we get a device api callback
    [[self.mockedChannelRegistrar expect] registerWithChannelID:OCMOCK_ANY
                                                channelLocation:OCMOCK_ANY
                                                    withPayload:OCMOCK_ANY
                                                     forcefully:NO];


    // The flag allowUnregisteringUserNotificationTypes should prevent unregistering notification types
    [[self.mockedApplication reject] registerUserNotificationSettings:OCMOCK_ANY];


    self.push.userPushNotificationsEnabled = NO;

    XCTAssertFalse(self.push.userPushNotificationsEnabled,
                   @"userPushNotificationsEnabled should be disabled when set to NO");

    XCTAssertFalse([self.dataStore boolForKey:UAUserPushNotificationsEnabledKey],
                   @"userPushNotificationsEnabled should be stored in standardUserDefaults");

    XCTAssertNoThrow([self.mockedApplication verify],
                     @"userPushNotificationsEnabled should unregister for remote notifications");
}

/**
 * Test channel ID is returned when both channel ID and channel location exist.
 */
- (void)testChannelID {
    [self.dataStore setValue:@"channel ID" forKey:@"UAChannelID"];
    [self.dataStore setValue:@"channel Location" forKey:@"UAChannelLocation"];

    XCTAssertEqualObjects(self.push.channelID, @"channel ID", @"Should return channel ID");
}

/**
 * Test channelID returns nil when channel ID does not exist.
 */
- (void)testChannelIDNoChannel {
    [self.dataStore removeObjectForKey:@"UAChannelID"];
    [self.dataStore setValue:@"channel Location" forKey:@"UAChannelLocation"];

    XCTAssertNil(self.push.channelID, @"Channel ID should be nil");
}

/**
 * Test channelID returns nil when channel location does not exist.
 */
- (void)testChannelIDNoLocation {
    [self.dataStore setValue:@"channel ID" forKey:@"UAChannelID"];
    [self.dataStore removeObjectForKey:@"UAChannelLocation"];

    XCTAssertNil(self.push.channelID, @"Channel ID should be nil");
}

/**
 * Test channel location is returned when both channel ID and channel location exist.
 */
- (void)testChannelLocation {
    [self.dataStore setValue:@"channel ID" forKey:@"UAChannelID"];
    [self.dataStore setValue:@"channel Location" forKey:@"UAChannelLocation"];

    XCTAssertEqualObjects(self.push.channelLocation, @"channel Location", @"Should return channel location");
}

/**
 * Test channelLocation returns nil when channel ID does not exist.
 */
- (void)testChannelLocationNoChannel {
    [self.dataStore removeObjectForKey:@"UAChannelID"];
    [self.dataStore setValue:@"channel Location" forKey:@"UAChannelLocation"];

    XCTAssertNil(self.push.channelLocation, @"Channel location should be nil");
}

/**
 * Test channelLocation returns nil when channel location does not exist.
 */
- (void)testChannelLocationNoLocation {
    [self.dataStore setValue:@"channel ID" forKey:@"UAChannelID"];
    [self.dataStore removeObjectForKey:@"UAChannelLocation"];

    XCTAssertNil(self.push.channelLocation, @"Channel location should be nil");
}


/**
 * Test handleRemoteNotification when auto badge is disabled does
 * not set the badge on the application
 */
- (void)testHandleNotificationAutoBadgeDisabled {
    self.push.autobadgeEnabled = NO;
    [[self.mockedApplication reject] setApplicationIconBadgeNumber:2];

    UANotificationContent *notificationContent = [UANotificationContent notificationWithNotificationInfo:self.notification];

    [self.push handleRemoteNotification:notificationContent foreground:YES completionHandler:^(UIBackgroundFetchResult result) {}];
    [self.push handleRemoteNotification:notificationContent foreground:NO completionHandler:^(UIBackgroundFetchResult result) {}];
}

/**
 * Test handleRemoteNotification when auto badge is enabled sets the badge
 * only when a notification comes in while the app is in the foreground
 */
- (void)testHandleNotificationAutoBadgeEnabled {
    self.push.autobadgeEnabled = YES;

    UANotificationContent *notificationContent = [UANotificationContent notificationWithNotificationInfo:self.notification];

    [[self.mockedApplication expect] setApplicationIconBadgeNumber:2];
    [self.push handleRemoteNotification:notificationContent foreground:YES completionHandler:^(UIBackgroundFetchResult result) {}];
    [self.mockedApplication verify];

    [[self.mockedApplication reject] setApplicationIconBadgeNumber:2];
    [self.push handleRemoteNotification:notificationContent foreground:NO completionHandler:^(UIBackgroundFetchResult result) {}];
}

/**
 * Test handleNotificationResponse sets the launched notificaitno response if
 * its the default identifier.
 */
- (void)testHandleNotificationLaunchNotification {
    self.push.launchNotificationResponse = nil;

    UANotificationResponse *response = [UANotificationResponse notificationResponseWithNotificationInfo:self.notification
                                                                                       actionIdentifier:UANotificationDefaultActionIdentifier
                                                                                           responseText:nil];

    [self.push handleNotificationResponse:response completionHandler:^{}];

    XCTAssertEqual(self.push.launchNotificationResponse, response);
}

/**
 * Test handleRemoteNotification when foreground and autobadge is enabled.
 */
- (void)testHandleRemoteNotificationForegroundAutobadgeEnabled {
    __block BOOL completionHandlerCalled = NO;

    UANotificationContent *expectedNotificationContent = [UANotificationContent notificationWithNotificationInfo:self.notification];

    self.push.autobadgeEnabled = YES;

    // Application should set icon badge number when autobadge is enabled
    [[self.mockedApplication expect] setApplicationIconBadgeNumber:expectedNotificationContent.badge.integerValue];

    [[self.mockedPushDelegate expect] receivedForegroundNotification:expectedNotificationContent completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^handler)() = obj;
        handler();
        return YES;
    }]];

    [[self.mockedPushDelegate reject] receivedBackgroundNotification:expectedNotificationContent completionHandler:OCMOCK_ANY];


    // Call handleRemoteNotification
    [self.push handleRemoteNotification:expectedNotificationContent foreground:YES completionHandler:^(UIBackgroundFetchResult result) {
        completionHandlerCalled = YES;
    }];

    [self.mockedApplication verify];
    [self.mockedPushDelegate verify];
    XCTAssertTrue(completionHandlerCalled);
}

/**
 * Test handleRemoteNotification when foreground and autobadge is disabled.
 */
- (void)testHandleRemoteNotificationForegroundAutobadgeDisabled {
    __block BOOL completionHandlerCalled = NO;

    UANotificationContent *expectedNotificationContent = [UANotificationContent notificationWithNotificationInfo:self.notification];

    self.push.autobadgeEnabled = NO;

    // Application should set icon badge number when autobadge is enabled
    [[self.mockedApplication reject] setApplicationIconBadgeNumber:expectedNotificationContent.badge.integerValue];

    [[self.mockedPushDelegate expect] receivedForegroundNotification:expectedNotificationContent completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^handler)() = obj;
        handler();
        return YES;
    }]];

    [[self.mockedPushDelegate reject] receivedBackgroundNotification:expectedNotificationContent completionHandler:OCMOCK_ANY];

    // Call handleRemoteNotification
    [self.push handleRemoteNotification:expectedNotificationContent foreground:YES completionHandler:^(UIBackgroundFetchResult result) {
        completionHandlerCalled = YES;
    }];

    [self.mockedApplication verify];
    [self.mockedPushDelegate verify];
    XCTAssertTrue(completionHandlerCalled);
}

/**
 * Test handleRemoteNotification when background push.
 */
- (void)testHandleRemoteNotificationBackground {
    __block BOOL completionHandlerCalled = NO;

    UANotificationContent *expectedNotificationContent = [UANotificationContent notificationWithNotificationInfo:self.notification];

    [[self.mockedPushDelegate reject] receivedForegroundNotification:expectedNotificationContent completionHandler:OCMOCK_ANY];

    [[self.mockedPushDelegate expect] receivedBackgroundNotification:expectedNotificationContent completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^handler)() = obj;
        handler();
        return YES;
    }]];

    // Call handleRemoteNotification
    [self.push handleRemoteNotification:expectedNotificationContent foreground:NO completionHandler:^(UIBackgroundFetchResult result) {
        completionHandlerCalled = YES;
    }];

    [self.mockedPushDelegate verify];
    XCTAssertTrue(completionHandlerCalled);
}

/**
 * Test handleRemoteNotification when no delegate is set.
 */
- (void)testHandleRemoteNotificationNoDelegate {
    __block BOOL completionHandlerCalled = NO;
    UANotificationContent *expectedNotificationContent = [UANotificationContent notificationWithNotificationInfo:self.notification];

    self.push.pushNotificationDelegate = nil;

    // Call handleRemoteNotification
    [self.push handleRemoteNotification:expectedNotificationContent foreground:YES completionHandler:^(UIBackgroundFetchResult result) {
        completionHandlerCalled = YES;
        XCTAssertEqual(result, UIBackgroundFetchResultNoData);
    }];

    XCTAssertTrue(completionHandlerCalled);
}

/**
 * Test handleNotificationResponse when launched from push.
 */
- (void)testHandleNotificationResponseLaunchedFromPush {
    UANotificationResponse *expectedNotificationLaunchFromPush = [UANotificationResponse notificationResponseWithNotificationInfo:self.notification
                                                                                                                 actionIdentifier:UANotificationDefaultActionIdentifier
                                                                                                                     responseText:@"test_response_text"];
    // delegate needs to be unresponsive to receivedNotificationResponse callback
    self.push.pushNotificationDelegate = nil;

    // Call handleNotificationResponse
    [self.push handleNotificationResponse:expectedNotificationLaunchFromPush completionHandler:^{
    }];

    // Check that the launchNotificationReponse is set to expected response
    XCTAssertEqualObjects(self.push.launchNotificationResponse, expectedNotificationLaunchFromPush);

    [self.mockedPushDelegate verify];
}

/**
 * Test handleNotificationResponse when not launched from push.
 */
- (void)testHandleNotificationResponseNotLaunchedFromPush {
    __block BOOL completionHandlerCalled = NO;

    UANotificationResponse *expectedNotificationNotLaunchedFromPush = [UANotificationResponse notificationResponseWithNotificationInfo:self.notification
                                                                                                                      actionIdentifier:@"test_action_identifier"
                                                                                                                          responseText:@"test_response_text"];

    [[self.mockedPushDelegate expect] receivedNotificationResponse:OCMOCK_ANY completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^handler)() = obj;
        handler();
        return YES;
    }]];

    // Call handleNotificationResponse
    [self.push handleNotificationResponse:expectedNotificationNotLaunchedFromPush completionHandler:^{
        completionHandlerCalled = YES;
    }];

    // Check that the launchNotificationReponse is not set
    XCTAssertNil(self.push.launchNotificationResponse);

    [self.mockedApplication verify];
    [self.mockedPushDelegate verify];
    XCTAssertTrue(completionHandlerCalled);
}

/**
 * Test handleNotificationResponse no delegate set.
 */
- (void)testHandleNotificationResponse {
    __block BOOL completionHandlerCalled = NO;

    self.push.pushNotificationDelegate = nil;

    UANotificationResponse *expectedNotification = [UANotificationResponse notificationResponseWithNotificationInfo:self.notification
                                                                                                   actionIdentifier:@"test_action_identifier"
                                                                                                       responseText:@"test_response_text"];

    // Call handleNotificationResponse
    [self.push handleNotificationResponse:expectedNotification completionHandler:^{
        completionHandlerCalled = YES;
    }];

    // Check that the launchNotificationReponse is not set
    XCTAssertNil(self.push.launchNotificationResponse);

    [self.mockedApplication verify];
    XCTAssertTrue(completionHandlerCalled);
}

/**
 * Test presentationOptionsForNotification when delegate method is unimplemented.
 */
- (void)testPresentationOptionsForNotificationNoDelegate {

    self.push.defaultPresentationOptions = UNNotificationPresentationOptionAlert;
    self.push.pushNotificationDelegate = nil;


    [[[self.mockedAirship stub] andReturn:self.push] push];

    UNNotificationPresentationOptions presentationOptions = [self.push presentationOptionsForNotification:self.mockedUNNotification];

    XCTAssertEqual(presentationOptions, self.push.defaultPresentationOptions);
}

/**
 * Test presentationOptionsForNotification when delegate method is implemented.
 */
- (void)testPresentationOptionsForNotification {

    [[[self.mockedAirship stub] andReturn:self.push] push];

    [[[self.mockedPushDelegate stub] andReturnValue:OCMOCK_VALUE(UNNotificationPresentationOptionAlert)] presentationOptionsForNotification:self.mockedUNNotification];

    UNNotificationPresentationOptions result = [self.push presentationOptionsForNotification:self.mockedUNNotification];

    XCTAssertEqual(result, UNNotificationPresentationOptionAlert);

    [self.mockedPushDelegate verify];
}

/**
 * Test updating tag groups calls the tag client for every pending mutation.
 */
- (void)testUpdateTagGroups {
    // Background task
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    // Channel
    self.push.channelID = @"someChannelID";
    self.push.channelLocation = @"someChannelLocation";


    // Expect a set mutation, return 200
    [[[self.mockTagGroupsAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];

        void (^completionHandler)(NSUInteger) = (__bridge void (^)(NSUInteger))arg;
        completionHandler(200);
    }] updateChannel:@"someChannelID"
     tagGroupsMutation:[OCMArg checkWithBlock:^BOOL(id obj) {
        UATagGroupsMutation *mutation = (UATagGroupsMutation *)obj;
        NSDictionary *expectedPayload = @{@"set": @{ @"group2": @[@"tag1"] } };
        return [expectedPayload isEqualToDictionary:[mutation payload]];
    }] completionHandler:OCMOCK_ANY];


    // Expect Add & Remove mutations, return 200
    [[[self.mockTagGroupsAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];

        void (^completionHandler)(NSUInteger) = (__bridge void (^)(NSUInteger))arg;
        completionHandler(200);
    }] updateChannel:@"someChannelID"
     tagGroupsMutation:[OCMArg checkWithBlock:^BOOL(id obj) {
        UATagGroupsMutation *mutation = (UATagGroupsMutation *)obj;
        NSDictionary *expectedPayload = @{@"add": @{ @"group1": @[@"tag1"] }, @"remove": @{ @"group1": @[@"tag2"] } };
        return [expectedPayload isEqualToDictionary:[mutation payload]];
    }] completionHandler:OCMOCK_ANY];

    [self.push addTags:@[@"tag1"] group:@"group1"];
    [self.push removeTags:@[@"tag2"] group:@"group1"];
    [self.push setTags:@[@"tag1"] group:@"group2"];

    [self.push updateRegistration];

    [self.mockTagGroupsAPIClient verify];
}


@end
