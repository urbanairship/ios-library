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


@interface UAPushTest : XCTestCase
@property(nonatomic, strong) id mockedApplication;
@property(nonatomic, strong) id mockedDeviceAPIClient;
@property(nonatomic, strong) id mockedAirshipClass;
@property(nonatomic, strong) id mockedAnalytics;
@property(nonatomic, strong) id mockedPushDelegate;
@property(nonatomic, strong) id mockRegistrationDelegate;
@property(nonatomic, strong) id mockRegistrationObserver;
@property(nonatomic, strong) id mockActionRunner;

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
    self.mockedDeviceAPIClient = [OCMockObject partialMockForObject:[UAPush shared].deviceAPIClient];

    self.mockedAnalytics = [OCMockObject niceMockForClass:[UAAnalytics class]];

    self.mockedAirshipClass =[OCMockObject niceMockForClass:[UAirship class]];
    [[[self.mockedAirshipClass stub] andReturn:self.mockedAirshipClass] shared];
    [[[self.mockedAirshipClass stub] andReturn:self.mockedAnalytics] analytics];

    self.mockedPushDelegate = [OCMockObject niceMockForProtocol:@protocol(UAPushNotificationDelegate)];
    [UAPush shared].pushNotificationDelegate = self.mockedPushDelegate;

    self.mockRegistrationDelegate = [OCMockObject mockForProtocol:@protocol(UARegistrationDelegate)];
    self.mockRegistrationObserver = [OCMockObject mockForProtocol:@protocol(UARegistrationObserver)];

    self.mockActionRunner = [OCMockObject mockForClass:[UAActionRunner class]];

    [UAPush shared].registrationDelegate = self.mockRegistrationDelegate;

    //remove all existing observers before adding our mock registration observer,
    //so we don't end up with angry zombie mocks between cases
    [[UAPush shared] removeObservers];
    [[UAPush shared] addObserver:self.mockRegistrationObserver];
}

- (void)tearDown {
    [super tearDown];
    [UAPush shared].pushNotificationDelegate = nil;
    [UAPush shared].registrationDelegate = nil;

    [self.mockedApplication stopMocking];
    [self.mockedDeviceAPIClient stopMocking];
    [self.mockedAnalytics stopMocking];
    [self.mockedAirshipClass stopMocking];
    [self.mockedPushDelegate stopMocking];
    [self.mockRegistrationDelegate stopMocking];
    [self.mockRegistrationObserver stopMocking];
    [self.mockActionRunner stopMocking];
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
    [[self.mockedDeviceAPIClient expect] unregisterWithData:OCMOCK_ANY
                                                  onSuccess:OCMOCK_ANY
                                                  onFailure:OCMOCK_ANY
                                                 forcefully:NO];

    [[self.mockedApplication expect] registerForRemoteNotificationTypes:UIRemoteNotificationTypeNone];

    [UAPush shared].pushEnabled = NO;

    XCTAssertFalse([UAPush shared].pushEnabled,
                   @"pushEnabled should be disabled when set to NO");

    XCTAssertFalse([[NSUserDefaults standardUserDefaults] boolForKey:UAPushEnabledSettingsKey],
                   @"pushEnabled should be stored in standardUserDefaults");

    XCTAssertNoThrow([self.mockedApplication verify],
                     @"pushEnabled should unregister for remote notifications");

    XCTAssertNoThrow([self.mockedDeviceAPIClient verify],
                     @"pushEnabled should make unregister with the device api client");
}

- (void)testSetQuietTimeFromTo {
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

- (void)testSetQuietTimeFromToNoTimeZone {
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

    XCTAssertNil([UAPush shared].timeZone, @"timezone should be able to be cleared");
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
    [[self.mockedDeviceAPIClient expect] registerWithData:OCMOCK_ANY
                                                onSuccess:OCMOCK_ANY
                                                onFailure:OCMOCK_ANY
                                               forcefully:YES];

    [[UAPush shared] setBadgeNumber:15];
    XCTAssertNoThrow([self.mockedApplication verify],
                     @"should update application icon badge number when its different");

    XCTAssertNoThrow([self.mockedDeviceAPIClient verify],
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
    [[self.mockedDeviceAPIClient reject] registerWithData:OCMOCK_ANY onSuccess:OCMOCK_ANY onFailure:OCMOCK_ANY forcefully:YES];

    [[UAPush shared] setBadgeNumber:15];
    XCTAssertNoThrow([self.mockedApplication verify],
                     @"should update application icon badge number when its different");

    XCTAssertNoThrow([self.mockedDeviceAPIClient verify],
                     @"should not update registration because autobadge is disabled");
}

- (void)testRegisterDeviceToken {
    [UAPush shared].notificationTypes = UIRemoteNotificationTypeSound;
    [UAPush shared].pushEnabled = YES;
    [UAPush shared].deviceToken = nil;

    NSData *token = [@"some-token" dataUsingEncoding:NSASCIIStringEncoding];
    [[self.mockedAnalytics expect] addEvent:OCMOCK_ANY];

    [[self.mockedDeviceAPIClient expect] registerWithData:OCMOCK_ANY
                                                onSuccess:OCMOCK_ANY
                                                onFailure:OCMOCK_ANY
                                               forcefully:NO];

    [[UAPush shared] registerDeviceToken:token];

    XCTAssertNoThrow([self.mockedAnalytics verify],
                     @"should add device registration event to analytics");

    XCTAssertNoThrow([self.mockedDeviceAPIClient verify],
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
    [[self.mockedDeviceAPIClient reject] registerWithData:OCMOCK_ANY onSuccess:OCMOCK_ANY onFailure:OCMOCK_ANY forcefully:NO];

    [[UAPush shared] registerDeviceToken:token];

    XCTAssertNoThrow([self.mockedAnalytics verify],
                     @"should not do anything if notificationTypes are not set");

    XCTAssertNoThrow([self.mockedDeviceAPIClient verify],
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

    [[self.mockedDeviceAPIClient expect] registerWithData:OCMOCK_ANY onSuccess:OCMOCK_ANY onFailure:OCMOCK_ANY forcefully:YES];
    [[UAPush shared] updateRegistrationForcefully:YES];
    XCTAssertNoThrow([self.mockedDeviceAPIClient verify],
                     @"updateRegistration should update registration when it has a valid token and the app is not in the background");

    // Verify it skips registration if device token is nil
    [UAPush shared].deviceToken = nil;

    [[self.mockedDeviceAPIClient reject] registerWithData:OCMOCK_ANY onSuccess:OCMOCK_ANY onFailure:OCMOCK_ANY forcefully:YES];
    [[UAPush shared] updateRegistrationForcefully:YES];
    XCTAssertNoThrow([self.mockedDeviceAPIClient verify],
                     @"updateRegistration should skip registering if device token is nil");


    // Verify it skips registration application state is background
    [UAPush shared].deviceToken = @"some-token";
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateBackground)] applicationState];

    [[self.mockedDeviceAPIClient reject] registerWithData:OCMOCK_ANY onSuccess:OCMOCK_ANY onFailure:OCMOCK_ANY forcefully:YES];
    [[UAPush shared] updateRegistrationForcefully:YES];
    XCTAssertNoThrow([self.mockedDeviceAPIClient verify],
                     @"updateRegistration should skip registering if app is in the background");
}

- (void)testUpdateRegistrationForcefullyPushDisabled {
    [UAPush shared].pushEnabled = NO;
    [UAPush shared].deviceToken = validDeviceToken;
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:UAPushNeedsUnregistering];

    [[self.mockedDeviceAPIClient expect] unregisterWithData:OCMOCK_ANY onSuccess:OCMOCK_ANY onFailure:OCMOCK_ANY forcefully:NO];
    [[UAPush shared] updateRegistrationForcefully:NO];
    XCTAssertNoThrow([self.mockedDeviceAPIClient verify],
                     @"updateRegistration should unregister when it has a valid token and the app is not in the background");

    // Verify it skips unregistering if UAPushNeedsUnregistering is NO
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:UAPushNeedsUnregistering];

    [[self.mockedDeviceAPIClient reject] unregisterWithData:OCMOCK_ANY onSuccess:OCMOCK_ANY onFailure:OCMOCK_ANY forcefully:YES];
    [[UAPush shared] updateRegistrationForcefully:NO];
    XCTAssertNoThrow([self.mockedDeviceAPIClient verify],
                     @"updateRegistration should skip unregistering UAPushNeedsUnregistering is NO");

    // Verify it skips registration if device token is nil
    [UAPush shared].deviceToken = nil;
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:UAPushNeedsUnregistering];

    [[self.mockedDeviceAPIClient reject] unregisterWithData:OCMOCK_ANY onSuccess:OCMOCK_ANY onFailure:OCMOCK_ANY forcefully:YES];
    [[UAPush shared] updateRegistrationForcefully:NO];
    XCTAssertNoThrow([self.mockedDeviceAPIClient verify],
                     @"updateRegistration should skip unregistering if device token is nil");


    // Verify it skips registration application state is background
    [UAPush shared].deviceToken = @"some-token";
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateBackground)] applicationState];

    [[self.mockedDeviceAPIClient reject] unregisterWithData:OCMOCK_ANY onSuccess:OCMOCK_ANY onFailure:OCMOCK_ANY forcefully:NO];
    [[UAPush shared] updateRegistrationForcefully:NO];
    XCTAssertNoThrow([self.mockedDeviceAPIClient verify], @"updateRegistration should skip unregistering if app is in the background");
}

//when push is enabled, updateRegistration should result in a registerDeviceTokenSucceeded callback
//to the observer and delegate on success
- (void)testUpdateRegistrationPushEnabledSuccess {

    //the device api client should receive a registration call.
    //in this case, we'll call the success block immediately.
    [[[self.mockedDeviceAPIClient expect] andDo:^(NSInvocation *invocation){
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UADeviceAPIClientSuccessBlock successBlock = (__bridge UADeviceAPIClientSuccessBlock) arg;
        successBlock();
    }] registerWithData:[OCMArg any] onSuccess:[OCMArg any] onFailure:[OCMArg any] forcefully:NO];

    //we should get success callbacks on both the delegate and observer
    [[self.mockRegistrationDelegate expect] registerDeviceTokenSucceeded];
    [[self.mockRegistrationObserver expect] registerDeviceTokenSucceeded];

    //enable push without calling custom setter
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:UAPushEnabledSettingsKey];
    [[UAPush shared] updateRegistration];
}

//when push is enabled, updateRegistration should result in a registerDeviceTokenFailed callback
//to the observer and delegate on failure
- (void)testUpdateRegistrationCallbacksPushEnabledFailure {

    //the device api client should receive an registration call.
    //in this case, we'll call the failure block immediately.
    [[[self.mockedDeviceAPIClient expect] andDo:^(NSInvocation *invocation){
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UADeviceAPIClientFailureBlock failureBlock = (__bridge UADeviceAPIClientFailureBlock) arg;
        //passing nil here instead of the usual UAHTTPRequest argument for convenience
        failureBlock(nil);
    }] registerWithData:[OCMArg any] onSuccess:[OCMArg any] onFailure:[OCMArg any] forcefully:NO];

    //we should get failure callbacks on both the delegate and observer
    [[self.mockRegistrationDelegate expect] registerDeviceTokenFailed:[OCMArg any]];
    [[self.mockRegistrationObserver expect] registerDeviceTokenFailed:[OCMArg any]];

    //enable push without calling custom setter
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:UAPushEnabledSettingsKey];
    [[UAPush shared] updateRegistration];
}

//when push is disabled, updateRegistration should result in a unregisterDeviceTokenSucceeded callback
//to the observer and delegate on success
- (void)testUpdateRegistrationCallbacksPushDisabledSuccess {

    //the device api client should receive an unregistration call.
    //in this case, we'll call the success block immediately.
    [[[self.mockedDeviceAPIClient expect] andDo:^(NSInvocation *invocation){
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UADeviceAPIClientSuccessBlock successBlock = (__bridge UADeviceAPIClientSuccessBlock) arg;
        successBlock();
    }] unregisterWithData:[OCMArg any] onSuccess:[OCMArg any] onFailure:[OCMArg any] forcefully:NO];

    //we should get success callbacks on both the delegate and observer
    [[self.mockRegistrationDelegate expect] unregisterDeviceTokenSucceeded];
    [[self.mockRegistrationObserver expect] unregisterDeviceTokenSucceeded];

    //disable push without calling custom setter
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:UAPushEnabledSettingsKey];
    [[UAPush shared] updateRegistration];
}

//when push is disabled, updateRegistration should result in a unregisterDeviceTokenFailed callback
//to the observer and delegate on failure
- (void)testUpdateRegistrationCallbacksPushDisabledFailure {

    //the device api client should receive an unregistration call.
    //in this case, we'll call the failure block immediately.
    [[[self.mockedDeviceAPIClient expect] andDo:^(NSInvocation *invocation){
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UADeviceAPIClientFailureBlock failureBlock = (__bridge UADeviceAPIClientFailureBlock) arg;
        //passing nil here instead of the usual UAHTTPRequest argument for convenience
        failureBlock(nil);
    }] unregisterWithData:[OCMArg any] onSuccess:[OCMArg any] onFailure:[OCMArg any] forcefully:NO];

    //we should get failure callbacks on both the delegate and observer
    [[self.mockRegistrationDelegate expect] unregisterDeviceTokenFailed:[OCMArg any]];
    [[self.mockRegistrationObserver expect] unregisterDeviceTokenFailed:[OCMArg any]];

    //disable push without calling custom setter
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:UAPushEnabledSettingsKey];
    [[UAPush shared] updateRegistration];
}


- (void)testRegistrationPayload {
    id registrationPayloadClassMock = [OCMockObject mockForClass:[UADeviceRegistrationPayload class]];
    [UAPush shared].alias = @"ALIAS";
    [UAPush shared].deviceTagsEnabled = YES;
    [UAPush shared].tags = @[@"tag-one"];

    // Set up badge
    [UAPush shared].autobadgeEnabled = YES;
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE((NSInteger)30)] applicationIconBadgeNumber];

    // Set quiet time
    [[UAPush shared] setQuietTimeEnabled:YES];
    [[UAPush shared] setQuietTimeFrom:[NSDate dateWithTimeIntervalSince1970:0]
                                   to:[NSDate dateWithTimeIntervalSince1970:10]
                         withTimeZone:[NSTimeZone timeZoneWithName:@"Pacific/Auckland"]];


    [[registrationPayloadClassMock expect] payloadWithAlias:@"ALIAS"
                                                   withTags:@[@"tag-one"]
                                               withTimeZone:@"Pacific/Auckland"
                                              withQuietTime:[UAPush shared].quietTime
                                                  withBadge:@30];
    [[UAPush shared] registrationPayload];
    XCTAssertNoThrow([registrationPayloadClassMock verify],
                     @"registrationPayload is not being created with expected values");
    [registrationPayloadClassMock stopMocking];
}

- (void)testRegistrationPayloadDeviceTagsDisabled {
    id registrationPayloadClassMock = [OCMockObject mockForClass:[UADeviceRegistrationPayload class]];
    [UAPush shared].deviceTagsEnabled = NO;
    [UAPush shared].tags = @[@"tag-one"];

    [[registrationPayloadClassMock expect] payloadWithAlias:OCMOCK_ANY
                                                   withTags:nil
                                               withTimeZone:OCMOCK_ANY
                                              withQuietTime:OCMOCK_ANY
                                                  withBadge:OCMOCK_ANY];
    [[UAPush shared] registrationPayload];
    XCTAssertNoThrow([registrationPayloadClassMock verify],
                     @"registrationPayload should not include tags if device tags is disabled");
    [registrationPayloadClassMock stopMocking];
}

- (void)testRegistrationPayloadAutoBadgeDisabled {
    id registrationPayloadClassMock = [OCMockObject mockForClass:[UADeviceRegistrationPayload class]];
    [UAPush shared].autobadgeEnabled = NO;
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(30)] applicationIconBadgeNumber];

    [[registrationPayloadClassMock expect] payloadWithAlias:OCMOCK_ANY
                                                   withTags:OCMOCK_ANY
                                               withTimeZone:OCMOCK_ANY
                                              withQuietTime:OCMOCK_ANY
                                                  withBadge:nil];
    [[UAPush shared] registrationPayload];

    XCTAssertNoThrow([registrationPayloadClassMock verify],
                     @"registrationPayload should not be created with badge if autobadge is disabled");
    [registrationPayloadClassMock stopMocking];
}

- (void)testRegistrationPayloadQuietTime {
    id registrationPayloadClassMock = [OCMockObject mockForClass:[UADeviceRegistrationPayload class]];

    [[UAPush shared] setQuietTimeEnabled:NO];
    [[UAPush shared] setQuietTimeFrom:[NSDate dateWithTimeIntervalSince1970:0]
                                   to:[NSDate dateWithTimeIntervalSince1970:10]
                         withTimeZone:[NSTimeZone timeZoneWithName:@"Pacific/Auckland"]];

    [[registrationPayloadClassMock expect] payloadWithAlias:OCMOCK_ANY
                                                   withTags:OCMOCK_ANY
                                               withTimeZone:nil
                                              withQuietTime:nil
                                                  withBadge:OCMOCK_ANY];
    [[UAPush shared] registrationPayload];

    XCTAssertNoThrow([registrationPayloadClassMock verify],
                     @"registrationPayload should not include quiet time if quiet time is disabled");
    [registrationPayloadClassMock stopMocking];
}

/**
 * Test handleNotification: and handleNotification:fetchCompletionHandler:
 * call the action runner with the correct arguments and report correctly to
 * analytics
 */
- (void)testHandleNotification {
    __block NSString *expectedSituation;
    __block UAActionFetchResult fetchResult = UAActionFetchResultNoData;

    BOOL (^runActionsCheck)(id obj) = ^(id obj) {
        NSDictionary *actions = (NSDictionary *)obj;
        if (actions.count < 1) {
            return NO;
        }

        // Validate incoming push action is added
        UAActionArguments *args = [actions valueForKey:kUAIncomingPushActionRegistryName];
        if (!args || ![args.situation isEqualToString:expectedSituation]) {
            return NO;
        }

        // Validate other push action is added
        args = [actions valueForKey:@"someActionKey"];
        if (!args || (![args.situation isEqualToString:expectedSituation] && ![args.value isEqualToString:@"someActionValue"])) {
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
    NSArray *situations = @[UASituationBackgroundPush, UASituationLaunchedFromPush, UASituationForegroundPush];

    for(NSInteger stateIndex = 0; stateIndex < 3; stateIndex++) {
        expectedSituation = [situations objectAtIndex:stateIndex];
        UIApplicationState applicationState = applicationStates[stateIndex];

        // Test handleNotification: first
        [[self.mockActionRunner expect] runActions:[OCMArg checkWithBlock:runActionsCheck] withCompletionHandler:[OCMArg checkWithBlock:handlerCheck]];
        [[self.mockedAnalytics expect] handleNotification:notification inApplicationState:applicationState];
        [[UAPush shared] handleNotification:notification applicationState:applicationState];

        XCTAssertNoThrow([self.mockActionRunner verify], @"handleNotification should run push actions with situation %@", expectedSituation);
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
            XCTAssertNoThrow([self.mockActionRunner verify], @"handleNotification should run push actions with situation %@", expectedSituation);
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
 * the hasEneteredBackground flag
 */
- (void)testApplicationDidEnterBackground {
    UAPush *push = [UAPush shared];
    push.hasEnteredBackground = NO;
    push.launchNotification = notification;

    [push applicationDidEnterBackground];
    XCTAssertTrue(push.hasEnteredBackground, @"applicationDidEnterBackground should set hasEnteredBackground to true");
    XCTAssertNil(push.launchNotification, @"applicationDidEnterBackground should clear the launch notification");
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
                      && [args.situation isEqualToString:UASituationLaunchedFromSpringBoard]
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

@end
