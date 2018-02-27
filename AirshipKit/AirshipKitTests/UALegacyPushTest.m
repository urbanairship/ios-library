/* Copyright 2018 Urban Airship and Contributors */

#import "UABaseTest.h"
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
#import "UANotificationCategory.h"
#import "UAPushReceivedEvent+Internal.h"
#import "UATagGroupsMutation+Internal.h"

@interface UALegacyPushTest : UABaseTest
@property (nonatomic, strong) id mockApplication;
@property (nonatomic, strong) id mockChannelRegistrar;
@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) id mockAnalytics;
@property (nonatomic, strong) id mockPushDelegate;
@property (nonatomic, strong) id mockRegistrationDelegate;
@property (nonatomic, strong) id mockActionRunner;
@property (nonatomic, strong) id mockUAUtils;
@property (nonatomic, strong) id mockUAUser;
@property (nonatomic, strong) id mockUIUserNotificationSettings;
@property (nonatomic, strong) id mockDefaultNotificationCategories;
@property (nonatomic, strong) id mockTagGroupsAPIClient;
@property (nonatomic, strong) id mockProcessInfo;

@property (nonatomic, strong) UAPush *push;
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;

@property (nonatomic, strong) NSDictionary *notification;
@property (nonatomic, strong) NSDictionary *emptyNotification;

@property (nonatomic, assign) NSUInteger testOSMajorVersion;

@property (nonatomic, strong) NSData *validAPNSDeviceToken;

@property (nonatomic, assign) UANotificationOptions notificationOptions;
@end

@implementation UALegacyPushTest

NSString *validLegacyDeviceToken = @"0123456789abcdef0123456789abcdef";

#pragma GCC diagnostic ignored "-Wdeprecated-declarations"

- (void)setUp {
    [super setUp];

    self.validAPNSDeviceToken = [validLegacyDeviceToken dataUsingEncoding:NSASCIIStringEncoding];
    assert([self.validAPNSDeviceToken length] <= 32);

    self.testOSMajorVersion = 8;
    self.mockProcessInfo = [self mockForClass:[NSProcessInfo class]];
    [[[self.mockProcessInfo stub] andReturn:self.mockProcessInfo] processInfo];

    [[[[self.mockProcessInfo stub] andDo:^(NSInvocation *invocation) {
        NSOperatingSystemVersion arg;
        [invocation getArgument:&arg atIndex:2];

        BOOL result = self.testOSMajorVersion >= arg.majorVersion;
        [invocation setReturnValue:&result];
    }] ignoringNonObjectArgs] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){0, 0, 0}];

    self.dataStore = [UAPreferenceDataStore preferenceDataStoreWithKeyPrefix:@"uapush.test."];
    [self.dataStore removeAll];
    
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

    // Set up a mocked application
    self.mockApplication = [self mockForClass:[UIApplication class]];
    [[[self.mockApplication stub] andReturn:self.mockApplication] sharedApplication];
    self.notificationOptions = UANotificationOptionNone;
    [[[[self.mockApplication stub] andDo:^(NSInvocation *invocation) {
        UIUserNotificationSettings *settings = [self convertUANotificationOptionsToUIUserNotificationSettings:self.notificationOptions];
        [invocation setReturnValue:&settings];
    }] ignoringNonObjectArgs] currentUserNotificationSettings];

    // Set up mocked UIUserNotificationSettings
    self.mockUIUserNotificationSettings = [self mockForClass:[UIUserNotificationSettings class]];

    // Set up a mocked device api client
    self.mockChannelRegistrar = [self mockForClass:[UAChannelRegistrar class]];
    self.push.channelRegistrar.delegate = nil;
    self.push.channelRegistrar = self.mockChannelRegistrar;

    self.mockAnalytics = [self mockForClass:[UAAnalytics class]];

    self.mockAirship =[self mockForClass:[UAirship class]];
    [[[self.mockAirship stub] andReturn:self.mockAirship] shared];
    [[[self.mockAirship stub] andReturn:self.mockAnalytics] analytics];
    [[[self.mockAirship stub] andReturn:self.dataStore] dataStore];

    self.mockPushDelegate = [self mockForProtocol:@protocol(UAPushNotificationDelegate)];
    self.push.pushNotificationDelegate = self.mockPushDelegate;

    self.mockRegistrationDelegate = [self mockForProtocol:@protocol(UARegistrationDelegate)];

    self.mockActionRunner = [self strictMockForClass:[UAActionRunner class]];

    self.mockUAUtils = [self mockForClass:[UAUtils class]];
    [[[self.mockUAUtils stub] andReturn:@"someDeviceID"] deviceID];

    self.mockUAUser = [self mockForClass:[UAUser class]];
    [[[self.mockAirship stub] andReturn:self.mockUAUser] inboxUser];
    [[[self.mockUAUser stub] andReturn:@"someUser"] username];

    self.mockDefaultNotificationCategories = [self mockForClass:[UANotificationCategories class]];

    self.push.registrationDelegate = self.mockRegistrationDelegate;

    self.mockTagGroupsAPIClient = [self mockForClass:[UATagGroupsAPIClient class]];
    self.push.tagGroupsAPIClient = self.mockTagGroupsAPIClient;
}

- (void)setUpOSVersionDependentStuff:(BOOL)legacy {
    
}

- (void)tearDown {
    self.push.pushNotificationDelegate = nil;
    self.push.registrationDelegate = nil;

    [self.dataStore removeAll];

    [super tearDown];
}

- (void)testSetDeviceToken {
    self.push.deviceToken = nil;

    self.push.deviceToken = @"invalid characters";

    XCTAssertNil(self.push.deviceToken, @"setDeviceToken should ignore device tokens with invalid characters.");


    self.push.deviceToken = validLegacyDeviceToken;
    XCTAssertEqualObjects(validLegacyDeviceToken, self.push.deviceToken, @"setDeviceToken should set tokens with valid characters");

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

- (void)testAddTagsToDeviceTagGroupWhenChannelTagRegistrationDisabled {
    // SETUP
    self.push.channelTagRegistrationEnabled = YES;
    
    // EXPECTATIONS
    id mockedTagGroupClass = [self mockForClass:[UATagGroupsMutation class]];
    [[mockedTagGroupClass reject] mutationToAddTags:OCMOCK_ANY group:OCMOCK_ANY];
    
    // TEST
    [self.push addTags:@[@"tag1"] group:@"device"];
    
    // VERIFY
    [mockedTagGroupClass verify];
}

- (void)testRemoveTagsFromDeviceTagGroupWhenChannelTagRegistrationDisabled {
    // SETUP
    self.push.channelTagRegistrationEnabled = NO;
    [self.push addTags:@[@"tag1"] group:@"device"];
    
    self.push.channelTagRegistrationEnabled = YES;
    
    // EXPECTATIONS
    id mockedTagGroupClass = [self mockForClass:[UATagGroupsMutation class]];
    [[mockedTagGroupClass reject] mutationToRemoveTags:OCMOCK_ANY group:OCMOCK_ANY];
    
    // TEST
    [self.push removeTags:@[@"tag1"] group:@"device"];
    
    // VERIFY
    [mockedTagGroupClass verify];
}

- (void)testSetTagsInDeviceTagGroupWhenChannelTagRegistrationDisabled {
    // SETUP
    self.push.channelTagRegistrationEnabled = YES;
    
    // EXPECTATIONS
    id mockedTagGroupClass = [self mockForClass:[UATagGroupsMutation class]];
    [[mockedTagGroupClass reject] mutationToSetTags:OCMOCK_ANY group:OCMOCK_ANY];
    
    // TEST
    [self.push setTags:@[@"tag1"] group:@"device"];
    
    // VERIFY
    [mockedTagGroupClass verify];
}

- (void)testAddEmptyTagListOrEmptyGroupDoesntAddTags {
    // SETUP

    // EXPECTATIONS
    id mockedTagGroupClass = [self mockForClass:[UATagGroupsMutation class]];
    [[mockedTagGroupClass reject] mutationToAddTags:OCMOCK_ANY group:OCMOCK_ANY];
    
    // TEST
    [self.push addTags:@[] group:@"group1"];
    [self.push addTags:@[@"tag1"] group:@""];
    
    // VERIFY
    [mockedTagGroupClass verify];
}

- (void)testRemoveEmptyTagListOrEmptyGroupDoesntRemoveTags {
    // SETUP
    [self.push addTags:@[@"tag1"] group:@"device"];

    // EXPECTATIONS
    id mockedTagGroupClass = [self mockForClass:[UATagGroupsMutation class]];
    [[mockedTagGroupClass reject] mutationToRemoveTags:OCMOCK_ANY group:OCMOCK_ANY];
    
    // TEST
    [self.push removeTags:@[] group:@"group1"];
    [self.push removeTags:@[@"tag1"] group:@""];
    
    // VERIFY
    [mockedTagGroupClass verify];
}

- (void)testSetEmptyTagListClearsTags {
    // SETUP
    NSArray *emptyArray = @[];
    
    // EXPECTATIONS
    id mockedTagGroupClass = [self mockForClass:[UATagGroupsMutation class]];
    [[[mockedTagGroupClass expect] andReturn:[[UATagGroupsMutation alloc] init]] mutationToSetTags:[OCMArg isEqual:emptyArray] group:OCMOCK_ANY];
    
    // TEST
    [self.push setTags:emptyArray group:@"group1"];
    
    // VERIFY
    [mockedTagGroupClass verify];
}

- (void)testSetWithEmptyGroupDoesntSetTags {
    // SETUP
    
    // EXPECTATIONS
    id mockedTagGroupClass = [self mockForClass:[UATagGroupsMutation class]];
    [[mockedTagGroupClass reject] mutationToSetTags:OCMOCK_ANY group:OCMOCK_ANY];
    
    // TEST
    [self.push setTags:@[@"tag1"] group:@""];
    
    // VERIFY
    [mockedTagGroupClass verify];
}

/**
 * Test enabling userPushNotificationsEnabled on >= iOS8 saves its settings
 * to NSUserDefaults and updates apns registration.
 */
- (void)testUserPushNotificationsEnabled {
    self.push.userPushNotificationsEnabled = NO;

    NSMutableSet *expectedCategories = [NSMutableSet set];
    for (UANotificationCategory *category in self.push.combinedCategories) {
        [expectedCategories addObject:[category asUIUserNotificationCategory]];
    }

    NSUInteger expectedTypes = self.push.notificationOptions;

    [[self.mockApplication expect] registerUserNotificationSettings:[OCMArg checkWithBlock:^BOOL(id obj) {
        UIUserNotificationSettings *settings = (UIUserNotificationSettings *)obj;
        return expectedTypes == settings.types && expectedCategories.count == settings.categories.count;
    }]];

    self.push.userPushNotificationsEnabled = YES;

    XCTAssertTrue(self.push.userPushNotificationsEnabled,
                  @"userPushNotificationsEnabled should be enabled when set to YES");

    XCTAssertTrue([self.dataStore boolForKey:UAUserPushNotificationsEnabledKey],
                  @"userPushNotificationsEnabled should be stored in standardUserDefaults");

    XCTAssertNoThrow([self.mockApplication verify],
                     @"userPushNotificationsEnabled should register for remote notifications");
}

/**
 * Test requireSettingsAppToDisableUserNotifications defaults to YES
 * and prevents userPushNotificationsEnabled from being disabled,
 * once it is enabled.
 */
-(void)testRequireSettingsAppToDisableUserNotifications {
    // Defaults to YES
    XCTAssertTrue(self.push.requireSettingsAppToDisableUserNotifications);

    // Verify it can be disabled
    self.push.requireSettingsAppToDisableUserNotifications = NO;
    XCTAssertFalse(self.push.requireSettingsAppToDisableUserNotifications);

    // Set up push for user notifications
    self.push.userPushNotificationsEnabled = YES;
    self.push.deviceToken = validLegacyDeviceToken;
    self.push.shouldUpdateAPNSRegistration = NO;

    // Prevent disabling userPushNotificationsEnabled
    self.push.requireSettingsAppToDisableUserNotifications = YES;

    // Verify we don't try to register when attempting to disable userPushNotificationsEnabled
    [[self.mockApplication reject] registerUserNotificationSettings:OCMOCK_ANY];

    self.push.userPushNotificationsEnabled = NO;

    // Should still be YES
    XCTAssertTrue(self.push.userPushNotificationsEnabled);

    // Verify we did not update user notification settings
    [self.mockApplication verify];
}

/**
 * Test disabling userPushNotificationsEnabled saves its settings
 * to NSUserDefaults and updates registration.
 */
- (void)testUserPushNotificationsDisable {
    self.push.userPushNotificationsEnabled = YES;
    self.push.deviceToken = validLegacyDeviceToken;
    self.push.shouldUpdateAPNSRegistration = NO;

    // Make sure we have previously registered types
    self.notificationOptions = UANotificationOptionBadge;

    // Make sure push is set to YES
    XCTAssertTrue(self.push.userPushNotificationsEnabled, @"userPushNotificationsEnabled should default to YES");

    // Add a device token so we get a device api callback
    [[self.mockChannelRegistrar expect] registerWithChannelID:OCMOCK_ANY
                                                channelLocation:OCMOCK_ANY
                                                    withPayload:OCMOCK_ANY
                                                     forcefully:NO];



    UIUserNotificationSettings *expected = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeNone
                                                                             categories:nil];

    [[self.mockApplication expect] registerUserNotificationSettings:expected];
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    self.push.requireSettingsAppToDisableUserNotifications = NO;
    self.push.userPushNotificationsEnabled = NO;

    XCTAssertFalse(self.push.userPushNotificationsEnabled,
                   @"userPushNotificationsEnabled should be disabled when set to NO");

    XCTAssertFalse([self.dataStore boolForKey:UAUserPushNotificationsEnabledKey],
                   @"userPushNotificationsEnabled should be stored in standardUserDefaults");

    XCTAssertNoThrow([self.mockApplication verify],
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
    [[self.mockChannelRegistrar expect] registerWithChannelID:OCMOCK_ANY
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
    [[self.mockChannelRegistrar expect] registerWithChannelID:OCMOCK_ANY
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
 * Test update apns registration when user notifications are enabled on.
 */
- (void)testUpdateAPNSRegistrationUserNotificationsEnabled {
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

    [[self.mockApplication expect] registerUserNotificationSettings:[OCMArg checkWithBlock:^BOOL(id obj) {
        UIUserNotificationSettings *settings = (UIUserNotificationSettings *)obj;
        expectedOptions = (UANotificationOptions)settings;
        [self.push application:self.mockApplication didRegisterUserNotificationSettings:settings];
        return expectedTypes == settings.types && expectedCategories.count == settings.categories.count;
    }]];

    [[[self.mockRegistrationDelegate expect] andDo:^(NSInvocation *invocation) {
        [delegateCalled fulfill];
    }]  notificationRegistrationFinishedWithOptions:7 categories:[OCMArg checkWithBlock:^BOOL(id obj) {
        NSSet *categories = (NSSet *)obj;

        return (categories.count == expectedCategories.count);
    }]];

    [self.push updateAPNSRegistration];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    XCTAssertNoThrow([self.mockApplication verify]);
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
 * Test receiving a call to application:didRegisterForRemoteNotificationsWithDeviceToken: results in that call being forwarded to the registration delegate
 */
-(void)testPushForwardsDidRegisterForRemoteNotificationsWithDeviceTokenToRegistrationDelegateForeground {
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateActive)] applicationState];
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];
    
    XCTestExpectation *delegateCalled = [self expectationWithDescription:@"Registration delegate called"];
    
    [[[self.mockRegistrationDelegate expect] andDo:^(NSInvocation *invocation) {
        [delegateCalled fulfill];
    }]  apnsRegistrationSucceededWithDeviceToken:self.validAPNSDeviceToken];
    
    // Expect UAPush to update its registration
    XCTestExpectation *pushRegistrationUpdated = [self expectationWithDescription:@"Push registration updated"];
    [[[[self.mockChannelRegistrar expect] ignoringNonObjectArgs] andDo:^(NSInvocation *invocation) {
        [pushRegistrationUpdated fulfill];
    }] registerWithChannelID:OCMOCK_ANY channelLocation:OCMOCK_ANY withPayload:OCMOCK_ANY forcefully:OCMOCK_ANY];
    
    [self.push application:self.mockApplication didRegisterForRemoteNotificationsWithDeviceToken:self.validAPNSDeviceToken];
    
    // device token also should be set
    XCTAssertTrue([self.push.deviceToken isEqualToString:[UAUtils deviceTokenStringFromDeviceToken:self.validAPNSDeviceToken]]);
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
    
    [self.mockRegistrationDelegate verify];
    [self.mockChannelRegistrar verify];
}

/**
 * Test receiving a call to application:didRegisterForRemoteNotificationsWithDeviceToken: results in that call being forwarded to the registration delegate
 */
-(void)testPushForwardsDidRegisterForRemoteNotificationsWithDeviceTokenToRegistrationDelegateBackground {
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateBackground)] applicationState];
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];
        
    XCTestExpectation *delegateCalled = [self expectationWithDescription:@"Registration delegate called"];
    
    [[[self.mockRegistrationDelegate expect] andDo:^(NSInvocation *invocation) {
        [delegateCalled fulfill];
    }]  apnsRegistrationSucceededWithDeviceToken:self.validAPNSDeviceToken];
    
    // Expect UAPush to not update its registration
    [[[self.mockChannelRegistrar expect] ignoringNonObjectArgs] registerWithChannelID:OCMOCK_ANY
                                                                        channelLocation:OCMOCK_ANY
                                                                            withPayload:OCMOCK_ANY
                                                                             forcefully:OCMOCK_ANY];
    
    [self.push application:self.mockApplication didRegisterForRemoteNotificationsWithDeviceToken:self.validAPNSDeviceToken];
    
    // device token also should be set

    [self.push application:self.mockApplication didRegisterForRemoteNotificationsWithDeviceToken:self.validAPNSDeviceToken];
    
    // device token also should be set
    XCTAssertTrue([self.push.deviceToken isEqualToString:[UAUtils deviceTokenStringFromDeviceToken:self.validAPNSDeviceToken]]);
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
    
    [self.mockRegistrationDelegate verify];
}

/**
 * Test receiving a call to application:didFailToRegisterForRemoteNotificationsWithError: results in that call being forwarded to the registration delegate
 */
-(void)testPushForwardsDidFailToRegisterForRemoteNotificationsWithDeviceTokenToRegistrationDelegate {
    
    NSError *error = [NSError errorWithDomain:@"domain" code:100 userInfo:nil];
    
    XCTestExpectation *delegateCalled = [self expectationWithDescription:@"Registration delegate called"];
    
    [[[self.mockRegistrationDelegate expect] andDo:^(NSInvocation *invocation) {
        [delegateCalled fulfill];
    }]  apnsRegistrationFailedWithError:error];
    
    [self.push application:self.mockApplication didFailToRegisterForRemoteNotificationsWithError:error];
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
    
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
            if ((action.options & UANotificationActionOptionForeground) == UANotificationOptionNone) {
                XCTAssertTrue((action.options & UANotificationActionOptionAuthenticationRequired) > 0, @"Invalid options for action: %@", action.identifier);

            }
        }
    }

    self.push.requireAuthorizationForDefaultCategories = NO;
    for (UANotificationCategory *category in self.push.combinedCategories) {
        for (UANotificationAction *action in category.actions) {
            // Only check background actions
            if ((action.options & UANotificationActionOptionForeground) == UANotificationOptionNone) {
                XCTAssertFalse((action.options & UANotificationActionOptionAuthenticationRequired) > 0, @"Invalid options for action: %@", action.identifier);

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

    UANotificationCategory *defaultCategory = [UANotificationCategory categoryWithIdentifier:@"defaultCategory" actions:@[]  intentIdentifiers:@[] options:UANotificationCategoryOptionNone];
    UANotificationCategory *customCategory = [UANotificationCategory categoryWithIdentifier:@"customCategory" actions:@[]  intentIdentifiers:@[] options:UANotificationCategoryOptionNone];
    UANotificationCategory *anotherCustomCategory = [UANotificationCategory categoryWithIdentifier:@"anotherCustomCategory" actions:@[] intentIdentifiers:@[] options:UANotificationCategoryOptionNone];

    NSSet *defaultSet = [NSSet setWithArray:@[defaultCategory]];
    [[[self.mockDefaultNotificationCategories stub] andReturn:defaultSet] defaultCategoriesWithRequireAuth:self.push.requireAuthorizationForDefaultCategories];

    NSSet *customSet = [NSSet setWithArray:@[customCategory, anotherCustomCategory]];
    self.push.customCategories = customSet;

    NSSet *expectedSet = [NSSet setWithArray:@[defaultCategory, customCategory, anotherCustomCategory]];
    XCTAssertEqualObjects(self.push.combinedCategories, expectedSet);
}


/**
 * Test update apns registration when user notifications are disabled
 */
- (void)testUpdateAPNSRegistrationUserNotificationsDisabled {
    // Make sure we have previously registered types
    self.notificationOptions = UANotificationOptionBadge;

    self.push.userPushNotificationsEnabled = NO;
    UIUserNotificationSettings *expected = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeNone
                                                                             categories:nil];

    [[self.mockApplication expect] registerUserNotificationSettings:expected];
    [self.push updateAPNSRegistration];

    XCTAssertNoThrow([self.mockApplication verify],
                     @"should register UIUserNotificationTypeNone types and nil categories");
}


/**
 * Test update apns does not register for 0 types if already is registered for none.
 */
- (void)testUpdateAPNSRegistrationPushAlreadyDisabled {
    self.notificationOptions = UANotificationOptionNone;
    self.push.userPushNotificationsEnabled = NO;
    [self.push updateAPNSRegistration];

    // Make sure we do not register for none, if we are
    // already registered for none or it will prompt the user.
    [[self.mockApplication reject] registerUserNotificationSettings:OCMOCK_ANY];

    [self.push updateAPNSRegistration];

    XCTAssertNoThrow([self.mockApplication verify],
                     @"should register UIUserNotificationTypeNone types and nil categories");
}

- (void)testSetBadgeNumberAutoBadgeEnabled {
    // Set the right values so we can check if a device api client call was made or not
    self.push.userPushNotificationsEnabled = YES;
    self.push.autobadgeEnabled = YES;
    self.push.deviceToken = validLegacyDeviceToken;

    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSInteger)30)] applicationIconBadgeNumber];
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    [[self.mockApplication expect] setApplicationIconBadgeNumber:15];
    
    // Expect UAPush to update its registration
    XCTestExpectation *pushRegistrationUpdated = [self expectationWithDescription:@"Push registration updated"];
    [[[self.mockChannelRegistrar expect] andDo:^(NSInvocation *invocation) {
        [pushRegistrationUpdated fulfill];
    }] registerWithChannelID:OCMOCK_ANY channelLocation:OCMOCK_ANY withPayload:OCMOCK_ANY forcefully:YES];
    
    [self.push setBadgeNumber:15];

    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNoThrow([self.mockApplication verify],
                     @"should update application icon badge number when its different");

    XCTAssertNoThrow([self.mockChannelRegistrar verify],
                     @"should update registration so autobadge works");
}

- (void)testSetBadgeNumberNoChange {
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSInteger)30)] applicationIconBadgeNumber];
    [[self.mockApplication reject] setApplicationIconBadgeNumber:30];

    [self.push setBadgeNumber:30];
    XCTAssertNoThrow([self.mockApplication verify],
                     @"should not update application icon badge number if there is no change");
}

- (void)testSetBadgeNumberAutoBadgeDisabled {
    self.push.userPushNotificationsEnabled = YES;
    self.push.deviceToken = validLegacyDeviceToken;

    self.push.autobadgeEnabled = NO;

    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSInteger)30)] applicationIconBadgeNumber];
    [[self.mockApplication expect] setApplicationIconBadgeNumber:15];

    // Reject device api client registration because autobadge is not enabled
    [[self.mockChannelRegistrar reject] registerWithChannelID:OCMOCK_ANY
                                                channelLocation:OCMOCK_ANY
                                                    withPayload:OCMOCK_ANY
                                                     forcefully:YES];
    [self.push setBadgeNumber:15];
    XCTAssertNoThrow([self.mockApplication verify],
                     @"should update application icon badge number when its different");

    XCTAssertNoThrow([self.mockChannelRegistrar verify],
                     @"should not update registration because autobadge is disabled");
}

- (void)testResetBadge {
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSInteger)30)] applicationIconBadgeNumber];
    [[self.mockApplication expect] setApplicationIconBadgeNumber:0];
    
    [self.push resetBadge];
    XCTAssertNoThrow([self.mockApplication verify],
                     @"should set application icon badge number to 0");
}

- (void)testResetBadgeNumberNoChange {
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSInteger)0)] applicationIconBadgeNumber];
    [[self.mockApplication reject] setApplicationIconBadgeNumber:0];
    
    [self.push resetBadge];
    XCTAssertNoThrow([self.mockApplication verify],
                     @"should not update application icon badge number if there is no change");
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
    XCTAssertTrue(self.push.userPushNotificationsEnabled, @"default user notification value taking affect.");

    [self.dataStore removeAll];
    
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
    [[self.mockChannelRegistrar reject] registerWithChannelID:OCMOCK_ANY
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
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    // Test when channel creation is disabled
    self.push.channelCreationEnabled = NO;
    [[self.mockChannelRegistrar reject] registerWithChannelID:OCMOCK_ANY channelLocation:OCMOCK_ANY withPayload:OCMOCK_ANY forcefully:NO];

    [self.push updateChannelRegistrationForcefully:NO];

    [self.mockChannelRegistrar verify];
}

/**
 * Tests update registration when background task is invalid.
 */
- (void)testChannelCreationBackgroundInvalid {
    
    // Prevent beginRegistrationBackgroundTask early return
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE(UIBackgroundTaskInvalid)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];
    
    // Test when channel creation is enabled
    self.push.channelCreationEnabled = YES;
    [[self.mockChannelRegistrar reject] registerWithChannelID:OCMOCK_ANY channelLocation:OCMOCK_ANY withPayload:OCMOCK_ANY forcefully:NO];
    
    [self.push updateChannelRegistrationForcefully:NO];
    
    [self.mockChannelRegistrar verify];
}

/**
 * Tests update registration when channel creation flag is enabled.
 */
- (void)testChannelCreationFlagEnabled {

    // Prevent beginRegistrationBackgroundTask early return
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    // Test when channel creation is enabled
    self.push.channelCreationEnabled = YES;
    
    // Expect UAPush to update its registration
    XCTestExpectation *pushRegistrationUpdated = [self expectationWithDescription:@"Push registration updated"];
    [[[self.mockChannelRegistrar expect] andDo:^(NSInvocation *invocation) {
        [pushRegistrationUpdated fulfill];
    }] registerWithChannelID:OCMOCK_ANY channelLocation:OCMOCK_ANY withPayload:OCMOCK_ANY forcefully:NO];
    
    [self.push updateChannelRegistrationForcefully:NO];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    [self.mockChannelRegistrar verify];
}

/**
 * Tests that registration updates when channel creation flag is enabled.
 */
- (void)testEnableChannelCreation {
    // Prevent beginRegistrationBackgroundTask early return
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    // set an option so channel registration happens
    self.notificationOptions = UANotificationOptionAlert;

    // Test when channel creation starts disabled
    self.push.channelCreationEnabled = NO;
    [[self.mockApplication expect] registerUserNotificationSettings:[OCMArg checkWithBlock:^BOOL(id obj) {
        UANotificationOptions options = [self convertUIUserNotificationSettingsToUANotificationOptions:(UIUserNotificationSettings *)obj];
        return (options == UANotificationOptionNone);
    }]];
    
    // TEST
    [self.push enableChannelCreation];
    
    // VERIFY
    [self.mockApplication verify];
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
    id mockDataStore = [self mockForClass:[UAPreferenceDataStore class]];
    [[[mockDataStore stub] andReturn:@"someChannelLocation"] stringForKey:UAPushChannelLocationKey];
    [[[mockDataStore stub] andReturn:@"someChannelID"] stringForKey:UAPushChannelIDKey];

    self.push =  [UAPush pushWithConfig:config dataStore:mockDataStore];

    // Ensure channel creation enabled is YES
    XCTAssertTrue(self.push.channelCreationEnabled);
}

- (void)testUpdateRegistrationForcefullyPushEnabled {
    self.push.userPushNotificationsEnabled = YES;
    self.push.deviceToken = validLegacyDeviceToken;

    // Check every app state.  We want to allow manual registration in any state.
    for(int i = UIApplicationStateActive; i < UIApplicationStateBackground; i++) {
        UIApplicationState state = (UIApplicationState)i;
        self.push.registrationBackgroundTask = UIBackgroundTaskInvalid;

        [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE(state)] applicationState];

        // Expect UAPush to update its registration
        XCTestExpectation *pushRegistrationUpdated = [self expectationWithDescription:@"Push registration updated"];
        [[[self.mockChannelRegistrar expect] andDo:^(NSInvocation *invocation) {
            [pushRegistrationUpdated fulfill];
        }] registerWithChannelID:OCMOCK_ANY channelLocation:OCMOCK_ANY withPayload:OCMOCK_ANY forcefully:YES];

        [[[self.mockApplication expect] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

        [self.push updateChannelRegistrationForcefully:YES];
        
        [self waitForExpectationsWithTimeout:1 handler:nil];

        XCTAssertNoThrow([self.mockChannelRegistrar verify],
                         @"updateRegistration should register with the channel registrar if push is enabled.");

        XCTAssertNoThrow([self.mockApplication verify], @"A background task should be requested for every update");
    }
}


- (void)testUpdateRegistrationForcefullyPushDisabled {
    self.push.userPushNotificationsEnabled = NO;
    self.push.deviceToken = validLegacyDeviceToken;

    // Expect UAPush to update its registration
    XCTestExpectation *pushRegistrationUpdated = [self expectationWithDescription:@"Push registration updated"];

    // Add a device token so we get a device api callback
    [[[self.mockChannelRegistrar expect] andDo:^(NSInvocation *invocation) {
        [pushRegistrationUpdated fulfill];
    }] registerWithChannelID:OCMOCK_ANY channelLocation:OCMOCK_ANY withPayload:OCMOCK_ANY forcefully:YES];

    [[[self.mockApplication expect] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    [self.push updateChannelRegistrationForcefully:YES];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNoThrow([self.mockChannelRegistrar verify],
                     @"updateRegistration should unregister with the channel registrar if push is disabled.");

    XCTAssertNoThrow([self.mockApplication verify], @"A background task should be requested for every update");
}

- (void)testUpdateRegistrationInvalidBackgroundTask {
    self.push.userPushNotificationsEnabled = YES;
    self.push.deviceToken = validLegacyDeviceToken;

    [[[self.mockApplication expect] andReturnValue:OCMOCK_VALUE((NSUInteger)UIBackgroundTaskInvalid)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    [[self.mockChannelRegistrar reject] registerWithChannelID:OCMOCK_ANY
                                                channelLocation:OCMOCK_ANY
                                                    withPayload:OCMOCK_ANY
                                                     forcefully:YES];

    [self.push updateChannelRegistrationForcefully:YES];


    XCTAssertNoThrow([self.mockChannelRegistrar verify],
                     @"updateRegistration should not call any registration without a valid background task");
}

- (void)testUpdateRegistrationExistingBackgroundTask {
    self.push.registrationBackgroundTask = 30;
    [[self.mockApplication reject] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    [self.push updateChannelRegistrationForcefully:YES];

    XCTAssertNoThrow([self.mockApplication verify], @"A background task should not be requested if one already exists");
}

/**
 * Test registration payload when pushTokenRegistrationEnabled is NO does not include device token
 */
- (void)testRegistrationPayloadPushTokenRegistrationEnabledNo {
    // Set up UAPush to give a full, opted in payload
    self.push.pushTokenRegistrationEnabled = NO;
    self.push.deviceToken = validLegacyDeviceToken;
    self.push.alias = @"ALIAS";
    self.push.channelTagRegistrationEnabled = YES;
    self.push.tags = @[@"tag-one"];
    self.push.autobadgeEnabled = NO;
    self.push.quietTimeEnabled = YES;
    self.push.timeZone = [NSTimeZone timeZoneWithName:@"Pacific/Auckland"];
    [self.push setQuietTimeStartHour:12 startMinute:0 endHour:12 endMinute:0];

    // Opt in requirement
    self.push.userPushNotificationsEnabled = YES;

    BOOL (^checkPayloadBlock)(id obj) = ^BOOL(id obj) {
        UAChannelRegistrationPayload *payload = (UAChannelRegistrationPayload *)obj;
        return payload.pushAddress == nil;
    };

    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    // Expect UAPush to update its registration
    XCTestExpectation *pushRegistrationUpdated = [self expectationWithDescription:@"Push registration updated"];
    
    [[[self.mockChannelRegistrar expect] andDo:^(NSInvocation *invocation) {
        [pushRegistrationUpdated fulfill];
    }] registerWithChannelID:OCMOCK_ANY channelLocation:OCMOCK_ANY withPayload:[OCMArg checkWithBlock:checkPayloadBlock] forcefully:YES];

    [self.push updateChannelRegistrationForcefully:YES];

    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNoThrow([self.mockChannelRegistrar verify],
                     @"payload is not being created with expected values");
}

/**
 * Test when backgroundPushNotificationsAllowed is YES when
 * device token is available, remote-notification background mode is enabled,
 * backgroundRefreshStatus is allowed, backgroundPushNotificationsEnabled is
 * enabled and pushTokenRegistrationEnabled is YES.
 */
- (void)testBackgroundPushNotificationsAllowed {
    self.push.deviceToken = validLegacyDeviceToken;
    self.push.backgroundPushNotificationsEnabled = YES;
    self.push.pushTokenRegistrationEnabled = YES;
    [[[self.mockAirship stub] andReturnValue:OCMOCK_VALUE(YES)] remoteNotificationBackgroundModeEnabled];
    [[[self.mockApplication stub] andReturnValue:@(UIBackgroundRefreshStatusAvailable)] backgroundRefreshStatus];
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE(YES)] isRegisteredForRemoteNotifications];

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
    [[[self.mockAirship stub] andReturnValue:OCMOCK_VALUE(YES)] remoteNotificationBackgroundModeEnabled];
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE(YES)] isRegisteredForRemoteNotifications];
    [[[self.mockApplication stub] andReturnValue:@(UIBackgroundRefreshStatusAvailable)] backgroundRefreshStatus];

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
    [[[self.mockAirship stub] andReturnValue:OCMOCK_VALUE(YES)] remoteNotificationBackgroundModeEnabled];
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE(YES)] isRegisteredForRemoteNotifications];
    [[[self.mockApplication stub] andReturnValue:@(UIBackgroundRefreshStatusAvailable)] backgroundRefreshStatus];
    self.push.deviceToken = validLegacyDeviceToken;


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
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE(YES)] isRegisteredForRemoteNotifications];
    [[[self.mockApplication stub] andReturnValue:@(UIBackgroundRefreshStatusAvailable)] backgroundRefreshStatus];
    self.push.deviceToken = validLegacyDeviceToken;

    [[[self.mockAirship stub] andReturnValue:OCMOCK_VALUE(NO)] remoteNotificationBackgroundModeEnabled];
    XCTAssertFalse(self.push.backgroundPushNotificationsAllowed,
                   @"BackgroundPushNotificationsAllowed should be NO");
}

/**
 * Test when backgroundPushNotificationsAllowed is NO when backgroundRefreshStatus is invalid.
 */
- (void)testBackgroundPushNotificationsDisallowedInvalidBackgroundRefreshStatus {
    self.push.userPushNotificationsEnabled = YES;
    self.push.backgroundPushNotificationsEnabled = YES;
    [[[self.mockAirship stub] andReturnValue:OCMOCK_VALUE(YES)] remoteNotificationBackgroundModeEnabled];
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE(YES)] isRegisteredForRemoteNotifications];
    self.push.deviceToken = validLegacyDeviceToken;

    [[[self.mockApplication stub] andReturnValue:@(UIBackgroundRefreshStatusRestricted)] backgroundRefreshStatus];

    XCTAssertFalse(self.push.backgroundPushNotificationsAllowed,
                   @"BackgroundPushNotificationsAllowed should be NO");
}

/**
 * Test that backgroundPushNotificationsAllowed is NO when not registered for remote notifications.
 */
- (void)testBackgroundPushNotificationsDisallowedNotRegisteredForRemoteNotifications {
    self.push.backgroundPushNotificationsEnabled = YES;
    [[[self.mockApplication stub] andReturnValue:@(UIBackgroundRefreshStatusAvailable)] backgroundRefreshStatus];
    [[[self.mockAirship stub] andReturnValue:OCMOCK_VALUE(YES)] remoteNotificationBackgroundModeEnabled];
    self.push.deviceToken = validLegacyDeviceToken;

    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE(NO)] isRegisteredForRemoteNotifications];
    XCTAssertFalse(self.push.backgroundPushNotificationsAllowed,
                   @"BackgroundPushNotificationsAllowed should be NO");
}

/**
 * Test when backgroundPushNotificationsAllowed is NO when
 * pushTokenRegistrationEnabled is NO.
 */
- (void)testBackgroundPushNotificationsPushTokenRegistrationEnabledNo {
    self.push.deviceToken = validLegacyDeviceToken;
    self.push.backgroundPushNotificationsEnabled = YES;
    self.push.pushTokenRegistrationEnabled = NO;
    [[[self.mockAirship stub] andReturnValue:OCMOCK_VALUE(YES)] remoteNotificationBackgroundModeEnabled];
    [[[self.mockApplication stub] andReturnValue:@(UIBackgroundRefreshStatusAvailable)] backgroundRefreshStatus];
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE(YES)] isRegisteredForRemoteNotifications];

    XCTAssertFalse(self.push.backgroundPushNotificationsAllowed,
                   @"BackgroundPushNotificationsAllowed should be NO");
}

/**
 * Test that UserPushNotificationAllowed is YES when there are authorized notification types set
 */
-(void)testUserPushNotificationsAllowed {
    self.push.userPushNotificationsEnabled = YES;
    self.push.pushTokenRegistrationEnabled = YES;
    self.push.deviceToken = validLegacyDeviceToken;
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE(YES)] isRegisteredForRemoteNotifications];

    self.notificationOptions = UANotificationOptionBadge;

    [self.push application:self.mockApplication didRegisterUserNotificationSettings:[self convertUANotificationOptionsToUIUserNotificationSettings:self.notificationOptions]];

    XCTAssertTrue(self.push.userPushNotificationsAllowed,
                  @"UserPushNotificationsAllowed should be YES");
}

/**
 * Test that UserPushNotificationAllowed is NO when there are no authorized notification types set
 */
-(void)testUserPushNotificationsAllowedNo {
    self.push.userPushNotificationsEnabled = YES;
    self.push.pushTokenRegistrationEnabled = NO;
    self.push.deviceToken = validLegacyDeviceToken;
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE(YES)] isRegisteredForRemoteNotifications];

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

    // Opt in requirement
    self.push.userPushNotificationsEnabled = YES;

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

    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];
    
    // Expect UAPush to update its registration
    XCTestExpectation *pushRegistrationUpdated = [self expectationWithDescription:@"Push registration updated"];
    
    [[[self.mockChannelRegistrar expect] andDo:^(NSInvocation *invocation) {
        [pushRegistrationUpdated fulfill];
    }] registerWithChannelID:OCMOCK_ANY channelLocation:OCMOCK_ANY withPayload:[OCMArg checkWithBlock:checkPayloadBlock] forcefully:YES];
    
    [self.push updateChannelRegistrationForcefully:YES];

    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNoThrow([self.mockChannelRegistrar verify],
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

    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];
    
    // Expect UAPush to update its registration
    XCTestExpectation *pushRegistrationUpdated = [self expectationWithDescription:@"Push registration updated"];
    
    [[[self.mockChannelRegistrar expect] andDo:^(NSInvocation *invocation) {
        [pushRegistrationUpdated fulfill];
    }] registerWithChannelID:OCMOCK_ANY channelLocation:OCMOCK_ANY withPayload:[OCMArg checkWithBlock:checkPayloadBlock] forcefully:YES];

    [self.push updateChannelRegistrationForcefully:YES];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    XCTAssertNoThrow([self.mockChannelRegistrar verify],
                     @"payload is including tags when device tags is NO");

}

- (void)testRegistrationPayloadAutoBadgeEnabled {
    self.push.userPushNotificationsEnabled = YES;
    self.push.autobadgeEnabled = YES;
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSInteger)30)] applicationIconBadgeNumber];

    // Check that the payload setTags is NO and the tags is nil
    BOOL (^checkPayloadBlock)(id obj) = ^(id obj) {
        UAChannelRegistrationPayload *payload = obj;
        return (BOOL)([payload.badge integerValue] == 30);
    };

    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];
    
    // Expect UAPush to update its registration
    XCTestExpectation *pushRegistrationUpdated = [self expectationWithDescription:@"Push registration updated"];
    
    [[[self.mockChannelRegistrar expect] andDo:^(NSInvocation *invocation) {
        [pushRegistrationUpdated fulfill];
    }] registerWithChannelID:OCMOCK_ANY channelLocation:OCMOCK_ANY withPayload:[OCMArg checkWithBlock:checkPayloadBlock] forcefully:YES];

    [self.push updateChannelRegistrationForcefully:YES];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    XCTAssertNoThrow([self.mockChannelRegistrar verify],
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

    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];
    
    // Expect UAPush to update its registration
    XCTestExpectation *pushRegistrationUpdated = [self expectationWithDescription:@"Push registration updated"];
    
    [[[self.mockChannelRegistrar expect] andDo:^(NSInvocation *invocation) {
        [pushRegistrationUpdated fulfill];
    }] registerWithChannelID:OCMOCK_ANY channelLocation:OCMOCK_ANY withPayload:[OCMArg checkWithBlock:checkPayloadBlock] forcefully:YES];

    [self.push updateChannelRegistrationForcefully:YES];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    XCTAssertNoThrow([self.mockChannelRegistrar verify],
                     @"payload should not include quiet time if quiet time is disabled");
}


/**
 * Test applicationDidBecomeActive, when run not after app was backgrounded, doesn't register
 */
- (void)testApplicationDidBecomeActive {
    self.push.userPushNotificationsEnabled = YES;

    self.notificationOptions = UANotificationOptionAlert;
    
    // SET EXPECTATIONS
    [[self.mockChannelRegistrar reject] registerWithChannelID:OCMOCK_ANY channelLocation:OCMOCK_ANY withPayload:OCMOCK_ANY forcefully:NO];
    
    // TEST
    [self.push applicationDidBecomeActive];
    
    // VERIFY
    [self.mockChannelRegistrar verify];
    
    XCTAssertTrue(self.push.userPromptedForNotifications);
    XCTAssertEqual(self.push.authorizedNotificationOptions,self.notificationOptions);
}

/**
 * Test applicationDidBecomeActive, when run after app was backgrounded, does register
 */
- (void)testApplicationDidBecomeActiveAfterBackgrounding {
    self.push.userPushNotificationsEnabled = YES;
    [self.dataStore setBool:YES forKey:UAPushChannelCreationOnForeground];
    
    self.notificationOptions = UANotificationOptionAlert;

    // Prevent beginRegistrationBackgroundTask early return
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    // SET EXPECTATIONS
    // Expect UAPush to update its registration
    XCTestExpectation *pushRegistrationUpdated = [self expectationWithDescription:@"Push registration updated"];
    
    [[[self.mockChannelRegistrar expect] andDo:^(NSInvocation *invocation) {
        [pushRegistrationUpdated fulfill];
    }] registerWithChannelID:OCMOCK_ANY channelLocation:OCMOCK_ANY withPayload:OCMOCK_ANY forcefully:NO];
    
    // TEST
    [self.push applicationDidBecomeActive];
    
    // VERIFY
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    [self.mockChannelRegistrar verify];
    
    XCTAssertTrue(self.push.userPromptedForNotifications);
    XCTAssertEqual(self.push.authorizedNotificationOptions,self.notificationOptions);
}

-(void)testApplicationBackgroundRefreshStatusChangedBackgroundAvailable {
    // SETUP
    [[[self.mockApplication stub] andReturnValue:@(UIBackgroundRefreshStatusAvailable)] backgroundRefreshStatus];
    self.notificationOptions = UANotificationOptionNone;
    
    // EXPECTATIONS
    XCTestExpectation *applicationCalled = [self expectationWithDescription:@"[UIApplication registerForRemoteNotifications] called"];
    [[[self.mockApplication expect] andDo:^(NSInvocation *invocation) {
        [applicationCalled fulfill];
    }] registerForRemoteNotifications];
    
    // TEST
    [self.push applicationBackgroundRefreshStatusChanged];
    
    // VERIFY
    [self waitForExpectationsWithTimeout:1 handler:nil];
    XCTAssertNoThrow([self.mockApplication verify], @"[UIApplication registerForRemoteNotifications] should be called");
}

-(void)testApplicationBackgroundRefreshStatusChangedBackgroundDenied {
    // SETUP
    [[[self.mockApplication stub] andReturnValue:@(UIBackgroundRefreshStatusDenied)] backgroundRefreshStatus];
    // set an option so channel registration happens
    self.notificationOptions = UANotificationOptionAlert;
        
    // EXPECTATIONS
    [[self.mockApplication expect] registerUserNotificationSettings:[OCMArg checkWithBlock:^BOOL(id obj) {
        UANotificationOptions options = [self convertUIUserNotificationSettingsToUANotificationOptions:(UIUserNotificationSettings *)obj];
        return (options == UANotificationOptionNone);
    }]];
    
    // TEST
    [self.push applicationBackgroundRefreshStatusChanged];
    
    // VERIFY
    XCTAssertNoThrow([self.mockApplication verify], @"[UIApplication registerUserNotificationSettings] should be called");
}

//
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

    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    // Expect UAPush to update its registration
    XCTestExpectation *pushRegistrationUpdated = [self expectationWithDescription:@"Push registration updated"];
    
    [[[self.mockChannelRegistrar expect] andDo:^(NSInvocation *invocation) {
        [pushRegistrationUpdated fulfill];
    }] registerWithChannelID:OCMOCK_ANY channelLocation:OCMOCK_ANY withPayload:OCMOCK_ANY forcefully:NO];

    [self.push applicationDidEnterBackground];

    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNoThrow([self.mockChannelRegistrar verify], @"Channel registration should be called");
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

    [self startNSNotificationCenterObservingWithBlock:^(NSNotification *notification) {
        XCTAssertEqualObjects(expectedUserInfo, notification.userInfo);
        [notificationFired fulfill];
    } notificationName:UAChannelCreatedEvent sender:self.push];

    [self.push channelCreated:@"someChannelID" channelLocation:@"someLocation" existing:YES];

    [self waitForExpectationsWithTimeout:10 handler:nil];
}

/**
 * Test new channel created posts an NSNotification of type UAChannelCreatedEvent
 */
- (void)testNewChannelCreatedNSNotification {

    id expectedUserInfo = @{ UAChannelCreatedEventExistingKey: @(NO),
                             UAChannelCreatedEventChannelKey:@"someChannelID" };

    XCTestExpectation *notificationFired = [self expectationWithDescription:@"Notification event fired"];
    
    [self startNSNotificationCenterObservingWithBlock:^(NSNotification *notification) {
        XCTAssertEqualObjects(expectedUserInfo, notification.userInfo);
        [notificationFired fulfill];
    } notificationName:UAChannelCreatedEvent sender:self.push];
    
    [self.push channelCreated:@"someChannelID" channelLocation:@"someLocation" existing:NO];

    [self waitForExpectationsWithTimeout:10 handler:nil];
}

/**
 * Test new channel created without a channel ID does basically nothing
 */
- (void)testNewChannelCreatedWithNilChannelID {
    // SETUP
    id expectedUserInfo = @{ UAChannelCreatedEventExistingKey: @(NO),
                             UAChannelCreatedEventChannelKey:@"someChannelID" };

    // EXPECTATIONS
    XCTestExpectation *notificationFired = [self expectationWithDescription:@"Notification event fired"];
    notificationFired.inverted = YES;
    [self startNSNotificationCenterObservingWithBlock:^(NSNotification *notification) {
        XCTAssertEqualObjects(expectedUserInfo, notification.userInfo);
        [notificationFired fulfill];
    } notificationName:UAChannelCreatedEvent sender:self.push];
    
    // TEST
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    [self.push channelCreated:nil channelLocation:@"someLocation" existing:NO];
#pragma clang diagnostic pop
    
    // VERIFY
    [self waitForExpectationsWithTimeout:0.1 handler:nil];
}

/**
 * Test channel updated posts an NSNotification of type UAChannelUpdatedEvent
 */
- (void)testChannelUpdatedNSNotification {
    UAChannelRegistrationPayload *payload = [[UAChannelRegistrationPayload alloc] init];

    self.push.deviceToken = validLegacyDeviceToken;
    self.push.channelID = @"someChannelID";
    self.push.channelLocation = @"someChannelLocation";

    XCTestExpectation *notificationFired = [self expectationWithDescription:@"Notification event fired"];

    [self startNSNotificationCenterObservingWithBlock:^(NSNotification *notification) {
        [notificationFired fulfill];
    } notificationName:UAChannelUpdatedEvent sender:self.push];
    
    [self.push registrationSucceededWithPayload:payload];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

/**
 * Test registration succeeded with channels and an up to date payload
 */
- (void)testRegistrationSucceeded {
    self.push.deviceToken = validLegacyDeviceToken;
    self.push.channelID = @"someChannelID";
    self.push.channelLocation = @"someChannelLocation";
    self.push.registrationBackgroundTask = 30;

    XCTestExpectation *delegateCalled = [self expectationWithDescription:@"Delegate called"];

    [[[self.mockRegistrationDelegate expect] andDo:^(NSInvocation *invocation) {
        [delegateCalled fulfill];
    }] registrationSucceededForChannelID:@"someChannelID" deviceToken:validLegacyDeviceToken];

    [[self.mockApplication expect] endBackgroundTask:30];

    [self.push registrationSucceededWithPayload:[self.push createChannelPayload]];

    [self waitForExpectationsWithTimeout:10 handler:nil];
    XCTAssertNoThrow([self.mockRegistrationDelegate verify], @"Delegate should be called");
    XCTAssertNoThrow([self.mockApplication verify], @"Should end the background task");
}

/**
 * Test registration succeeded with an out of date payload
 */
- (void)testRegistrationSucceededUpdateNeeded {
    self.push.deviceToken = validLegacyDeviceToken;
    self.push.channelID = @"someChannelID";
    self.push.channelLocation = @"someChannelLocation";
    self.push.registrationBackgroundTask = 30;

    XCTestExpectation *delegateCalled = [self expectationWithDescription:@"Delegate called"];

    [[[self.mockRegistrationDelegate expect] andDo:^(NSInvocation *invocation) {
        [delegateCalled fulfill];
    }]  registrationSucceededForChannelID:@"someChannelID" deviceToken:validLegacyDeviceToken];

    // Expect UAPush to update its registration
    XCTestExpectation *pushRegistrationUpdated = [self expectationWithDescription:@"Push registration updated"];
    
    [[[self.mockChannelRegistrar expect] andDo:^(NSInvocation *invocation) {
        [pushRegistrationUpdated fulfill];
    }] registerWithChannelID:OCMOCK_ANY channelLocation:OCMOCK_ANY withPayload:OCMOCK_ANY forcefully:NO];

    // Should not end the background task
    [[self.mockApplication reject] endBackgroundTask:30];

    // Call with an empty payload.  Should be different then the UAPush generated payload
    [self.push registrationSucceededWithPayload:[[UAChannelRegistrationPayload alloc] init]];

    [self waitForExpectationsWithTimeout:10 handler:nil];

    XCTAssertNoThrow([self.mockRegistrationDelegate verify], @"Delegate should be called");
    XCTAssertNoThrow([self.mockChannelRegistrar verify], @"Should call registerWithChannelID()");
    XCTAssertNoThrow([self.mockApplication verify], @"Should not end the background task");
}


/**
 * Test registration succeeded with no channel ID
 */
- (void)testRegistrationSucceededWithNoChannelID {
    self.push.deviceToken = validLegacyDeviceToken;
    
    XCTestExpectation *delegateCalled = [self expectationWithDescription:@"Delegate called"];
    delegateCalled.inverted = YES;
    
    [[[self.mockRegistrationDelegate reject] andDo:^(NSInvocation *invocation) {
        [delegateCalled fulfill];
    }]  registrationSucceededForChannelID:@"someChannelID" deviceToken:validLegacyDeviceToken];
    
    [[self.mockChannelRegistrar reject] registerWithChannelID:OCMOCK_ANY
                                                channelLocation:OCMOCK_ANY
                                                    withPayload:OCMOCK_ANY
                                                     forcefully:NO];
    
    // Call with an empty payload.  Should be different then the UAPush generated payload
    [self.push registrationSucceededWithPayload:[[UAChannelRegistrationPayload alloc] init]];
    
    [self waitForExpectationsWithTimeout:0.1 handler:nil];
    
    XCTAssertNoThrow([self.mockRegistrationDelegate verify], @"Delegate should be called");
    XCTAssertNoThrow([self.mockChannelRegistrar verify], @"Should not end the background task");
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

    [[self.mockApplication expect] endBackgroundTask:30];

    [self.push registrationFailedWithPayload:[[UAChannelRegistrationPayload alloc] init]];
    [self waitForExpectationsWithTimeout:10 handler:nil];

    XCTAssertNoThrow([self.mockRegistrationDelegate verify], @"Delegate should be called");
    XCTAssertNoThrow([self.mockApplication verify], @"Should end the background task");
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
 * Test migrating the userNotificationEnabled key no ops when its already set.
 */
- (void)testMigrateNewRegistrationFlowAlreadySet {
    // Set the UAUserPushNotificationsEnabledKey setting to NO
    [self.dataStore setBool:NO forKey:UAUserPushNotificationsEnabledKey];

    self.notificationOptions = UANotificationOptionAlert;

    // Force a migration
    [self.dataStore removeObjectForKey:UAPushEnabledSettingsMigratedKey];
    [self.push migratePushSettings];

    // Verify its still NO
    XCTAssertFalse([self.dataStore boolForKey:UAUserPushNotificationsEnabledKey]);
}
/**
 * Test migrating the userNotificationEnabled key does not set if the
 * current notification types is none.
 */
- (void)testMigrateNewRegistrationFlowDisabled {
    // Clear the UAUserPushNotificationsEnabledKey setting
    [self.dataStore removeObjectForKey:UAUserPushNotificationsEnabledKey];
    [self.dataStore removeObjectForKey:UAPushEnabledSettingsMigratedKey];

    self.notificationOptions = UANotificationOptionNone;

    [self.push migratePushSettings];

    // Verify it was not set
    XCTAssertNil([self.dataStore objectForKey:UAUserPushNotificationsEnabledKey]);
}

/**
 * Test migrating the userNotificationEnabled key does set to YES if the
 * current notification types is not none on.
 */
- (void)testMigrateNewRegistrationFlowEnabled {
    // Clear the UAUserPushNotificationsEnabledKey setting
    [self.dataStore removeObjectForKey:UAUserPushNotificationsEnabledKey];
    [self.dataStore removeObjectForKey:UAPushEnabledSettingsMigratedKey];

    self.notificationOptions = UANotificationOptionAlert;

    [self.push migratePushSettings];

    // Verify it was set to YES
    XCTAssertTrue([self.dataStore boolForKey:UAUserPushNotificationsEnabledKey]);
}

/**
 * Test migrating the UAUserPushNotificationsEnabledKey sets to the value
 * of the previous UAPushEnabledKey.
 */
- (void)testMigrateNewRegistrationFlowPreviousUAPushEnabledKeyWasSet {
    // Reset for migration
    [self.dataStore removeObjectForKey:UAUserPushNotificationsEnabledKey];
    [self.dataStore removeObjectForKey:UAPushEnabledSettingsMigratedKey];
    // Set the previous UAPushEnabledKey setting to YES
    [self.dataStore setValue:@YES forKey:UAPushEnabledKey];
    
    [self.push migratePushSettings];
    
    // Verify it was set to YES
    XCTAssertTrue([self.dataStore boolForKey:UAUserPushNotificationsEnabledKey]);
    XCTAssertNil([self.dataStore objectForKey:UAPushEnabledKey]);

    // Reset for migration
    [self.dataStore removeObjectForKey:UAUserPushNotificationsEnabledKey];
    [self.dataStore removeObjectForKey:UAPushEnabledSettingsMigratedKey];
    // Set the previous UAPushEnabledKey setting to NO
    [self.dataStore setValue:@NO forKey:UAPushEnabledKey];
    
    [self.push migratePushSettings];
    
    // Verify it was set to NO
    XCTAssertFalse([self.dataStore boolForKey:UAUserPushNotificationsEnabledKey]);
    XCTAssertNil([self.dataStore objectForKey:UAPushEnabledKey]);
}

/**
 * Test migrating only performs once.
 */
- (void)testMigrateNewRegistrationFlowOnlyOnce {
    // Clear the UAUserPushNotificationsEnabledKey setting
    [self.dataStore removeObjectForKey:UAUserPushNotificationsEnabledKey];
    [self.dataStore removeObjectForKey:UAPushEnabledSettingsMigratedKey];

    self.notificationOptions = UANotificationOptionAlert;

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
    self.push.userPushNotificationsEnabled = YES;
    self.push.deviceToken = validLegacyDeviceToken;
    self.push.shouldUpdateAPNSRegistration = NO;
    self.push.requireSettingsAppToDisableUserNotifications = NO;

    // Turn off allowing unregistering user notification types
    self.push.allowUnregisteringUserNotificationTypes = NO;

    // Make sure we have previously registered types
    self.notificationOptions = UANotificationOptionBadge;
    
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    // Expect UAPush to update its registration
    XCTestExpectation *pushRegistrationUpdated = [self expectationWithDescription:@"Push registration updated"];
    
    // Add a device token so we get a device api callback
    [[[self.mockChannelRegistrar expect] andDo:^(NSInvocation *invocation) {
        [pushRegistrationUpdated fulfill];
    }] registerWithChannelID:OCMOCK_ANY channelLocation:OCMOCK_ANY withPayload:OCMOCK_ANY forcefully:NO];

    // The flag allowUnregisteringUserNotificationTypes should prevent unregistering notification types
    [[self.mockApplication reject] registerUserNotificationSettings:OCMOCK_ANY];

    self.push.userPushNotificationsEnabled = NO;

    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertFalse(self.push.userPushNotificationsEnabled,
                   @"userPushNotificationsEnabled should be disabled when set to NO");

    XCTAssertFalse([self.dataStore boolForKey:UAUserPushNotificationsEnabledKey],
                   @"userPushNotificationsEnabled should be stored in standardUserDefaults");
    
    XCTAssertNoThrow([self.mockChannelRegistrar verify],
                     @"Should call channel registrar");

    XCTAssertNoThrow([self.mockApplication verify],
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
    [[self.mockApplication reject] setApplicationIconBadgeNumber:2];

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

    [[self.mockApplication expect] setApplicationIconBadgeNumber:2];
    [self.push handleRemoteNotification:notificationContent foreground:YES completionHandler:^(UIBackgroundFetchResult result) {}];
    [self.mockApplication verify];

    [[self.mockApplication reject] setApplicationIconBadgeNumber:2];
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
    [[self.mockApplication expect] setApplicationIconBadgeNumber:expectedNotificationContent.badge.integerValue];

    [[self.mockPushDelegate expect] receivedForegroundNotification:expectedNotificationContent completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^handler)(void) = obj;
        handler();
        return YES;
    }]];

    [[self.mockPushDelegate reject] receivedBackgroundNotification:expectedNotificationContent completionHandler:OCMOCK_ANY];


    // Call handleRemoteNotification
    [self.push handleRemoteNotification:expectedNotificationContent foreground:YES completionHandler:^(UIBackgroundFetchResult result) {
        completionHandlerCalled = YES;
    }];

    [self.mockApplication verify];
    [self.mockPushDelegate verify];
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
    [[self.mockApplication reject] setApplicationIconBadgeNumber:expectedNotificationContent.badge.integerValue];

    [[self.mockPushDelegate expect] receivedForegroundNotification:expectedNotificationContent completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^handler)(void) = obj;
        handler();
        return YES;
    }]];

    [[self.mockPushDelegate reject] receivedBackgroundNotification:expectedNotificationContent completionHandler:OCMOCK_ANY];

    // Call handleRemoteNotification
    [self.push handleRemoteNotification:expectedNotificationContent foreground:YES completionHandler:^(UIBackgroundFetchResult result) {
        completionHandlerCalled = YES;
    }];

    [self.mockApplication verify];
    [self.mockPushDelegate verify];
    XCTAssertTrue(completionHandlerCalled);
}

/**
 * Test handleRemoteNotification when background push.
 */
- (void)testHandleRemoteNotificationBackground {
    __block BOOL completionHandlerCalled = NO;

    UANotificationContent *expectedNotificationContent = [UANotificationContent notificationWithNotificationInfo:self.notification];

    [[self.mockPushDelegate reject] receivedForegroundNotification:expectedNotificationContent completionHandler:OCMOCK_ANY];

    [[self.mockPushDelegate expect] receivedBackgroundNotification:expectedNotificationContent completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^handler)(void) = obj;
        handler();
        return YES;
    }]];

    // Call handleRemoteNotification
    [self.push handleRemoteNotification:expectedNotificationContent foreground:NO completionHandler:^(UIBackgroundFetchResult result) {
        completionHandlerCalled = YES;
    }];

    [self.mockPushDelegate verify];
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

    [self.mockPushDelegate verify];
}

/**
 * Test handleNotificationResponse when not launched from push.
 */
- (void)testHandleNotificationResponseNotLaunchedFromPush {
    __block BOOL completionHandlerCalled = NO;

    UANotificationResponse *expectedNotificationNotLaunchedFromPush = [UANotificationResponse notificationResponseWithNotificationInfo:self.notification
                                                                                                                      actionIdentifier:@"test_action_identifier"
                                                                                                                          responseText:@"test_response_text"];

    [[self.mockPushDelegate expect] receivedNotificationResponse:OCMOCK_ANY completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^handler)(void) = obj;
        handler();
        return YES;
    }]];

    // Call handleNotificationResponse
    [self.push handleNotificationResponse:expectedNotificationNotLaunchedFromPush completionHandler:^{
        completionHandlerCalled = YES;
    }];

    // Check that the launchNotificationReponse is not set
    XCTAssertNil(self.push.launchNotificationResponse);

    [self.mockApplication verify];
    [self.mockPushDelegate verify];
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

    [self.mockApplication verify];
    XCTAssertTrue(completionHandlerCalled);
}

/**
 * Test updating tag groups calls the tag client for every pending mutation.
 */
- (void)testUpdateTagGroups {
    // Background task
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    // Channel
    self.push.channelID = @"someChannelID";
    self.push.channelLocation = @"someChannelLocation";

    XCTestExpectation *expectation = [self expectationWithDescription:@"Async update channel tag groups call"];

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

        [expectation fulfill];

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

    [self waitForExpectationsWithTimeout:1 handler:nil];

    [self.mockTagGroupsAPIClient verify];
}

- (void)testUpdateChannelTagGroupsWithInvalidBackground {
    // SETUP
    [self.dataStore setObject:@"someChannelLocation" forKey:UAPushChannelLocationKey];
    [self.dataStore setObject:@"someChannelID"       forKey:UAPushChannelIDKey];
    [self.push addTags:@[@"tag1"] group:@"group1"];

    // Prevent beginRegistrationBackgroundTask early return
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE(UIBackgroundTaskInvalid)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];
    
    // EXPECTATIONS
    [[self.mockTagGroupsAPIClient reject] updateChannel:OCMOCK_ANY tagGroupsMutation:OCMOCK_ANY completionHandler:OCMOCK_ANY];
   
    // TEST
    [self.push updateChannelTagGroups];
    
    // VERIFY
    [self.mockTagGroupsAPIClient verify];
}

/**
 * Test on first launch when user has not been prompted for notification.
 */
- (void)testNotificationNotPrompted {
    self.push.authorizedNotificationOptions = UANotificationOptionNone;
    XCTAssertFalse(self.push.userPromptedForNotifications);
}

/**
 * Test types are not set a second time when they are the same.
 */
- (void)testNotificationOptionsAuthorizedTwice {
    // SETUP
    self.push.authorizedNotificationOptions = UANotificationOptionAlert;
    
    // EXPECTATIONS
    [[self.mockRegistrationDelegate reject] notificationAuthorizedOptionsDidChange:UANotificationOptionAlert];

    // TEST
    self.push.authorizedNotificationOptions = UANotificationOptionAlert;
    
    // VERIFY
    XCTAssertNoThrow([self.mockRegistrationDelegate verify]);
    XCTAssertFalse(self.push.userPromptedForNotifications);
}

/**
 * Test registering a device token.
 */
- (void)testRegisteredDeviceToken {
    // SETUP
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateBackground)] applicationState];
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];
    
    // EXPECTATIONS
    // Expect UAPush to update its registration
    XCTestExpectation *pushRegistrationUpdated = [self expectationWithDescription:@"Push registration updated"];
    
    [[[self.mockChannelRegistrar expect] andDo:^(NSInvocation *invocation) {
        [pushRegistrationUpdated fulfill];
    }] registerWithChannelID:OCMOCK_ANY channelLocation:OCMOCK_ANY withPayload:OCMOCK_ANY forcefully:NO];

    NSData *token = [@"some-token" dataUsingEncoding:NSASCIIStringEncoding];
    
    [self.push application:self.mockApplication didRegisterForRemoteNotificationsWithDeviceToken:token];

    // VERIFY
    [self waitForExpectationsWithTimeout:1 handler:nil];

    [self.mockApplication verify];
    [self.mockChannelRegistrar verify];
    
    // Expect UAPush to receive the device token string
    // 736f6d652d746f6b656e = "some-token" in hex
    XCTAssertTrue([@"736f6d652d746f6b656e" isEqualToString:self.push.deviceToken]);
}

-(void)testDidRegisterForRemoteNotificationsWithDeviceTokenDoesntRegisterChannelWhenInBackground {
    // SETUP
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateBackground)] applicationState];
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    [self.dataStore setObject:@"someChannelLocation" forKey:UAPushChannelLocationKey];
    [self.dataStore setObject:@"someChannelID"       forKey:UAPushChannelIDKey];
    
    // EXPECTATIONS
    [[self.mockChannelRegistrar reject] registerWithChannelID:OCMOCK_ANY
                                                channelLocation:OCMOCK_ANY
                                                    withPayload:OCMOCK_ANY
                                                     forcefully:OCMOCK_ANY];
    
    // TEST
    NSData *token = [@"some-token" dataUsingEncoding:NSASCIIStringEncoding];
    [self.push application:self.mockApplication didRegisterForRemoteNotificationsWithDeviceToken:token];
    
    // VERIFY
    [self.mockApplication verify];
    [self.mockChannelRegistrar verify];

    // Expect UAPush to receive the device token string
    // 736f6d652d746f6b656e = "some-token" in hex
    XCTAssertTrue([@"736f6d652d746f6b656e" isEqualToString:self.push.deviceToken]);
}

-(void)testAuthorizedNotificationOptionsWhenPushNotificationsDisabled {
    // SETUP
    self.push.requireSettingsAppToDisableUserNotifications = NO;
    self.push.userPushNotificationsEnabled = NO;
    self.push.authorizedNotificationOptions = UANotificationOptionAlert;
    
    // TEST & VERIFY
    XCTAssert(self.push.authorizedNotificationOptions == UANotificationOptionNone);
}

/**
 * Utility methods
 */
-(UIUserNotificationSettings *)convertUANotificationOptionsToUIUserNotificationSettings:(UANotificationOptions)options {
    return [UIUserNotificationSettings settingsForTypes:(UIUserNotificationType)options categories:nil];;
}

-(UANotificationOptions)convertUIUserNotificationSettingsToUANotificationOptions:(UIUserNotificationSettings *)settings {
    return (UANotificationOptions)settings.types;
}

@end
