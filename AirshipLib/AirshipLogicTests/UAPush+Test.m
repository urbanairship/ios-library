#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import <OCMock/OCMConstraint.h>
#import "UAPush+Internal.h"
#import "UADeviceAPIClient.h"

@interface UAPush_Test : XCTestCase
@property(nonatomic, strong) id applicationClassMock;
@property(nonatomic, strong) id mockedApplication;
@property(nonatomic, strong) id mockedDeviceAPIClient;
@end

@implementation UAPush_Test

- (void)setUp {
    [super setUp];

    // Set up a mocked application
    self.mockedApplication = [OCMockObject niceMockForClass:[UIApplication class]];
    self.applicationClassMock = [OCMockObject mockForClass:[UIApplication class]];
    [[[self.applicationClassMock stub] andReturn:self.mockedApplication] sharedApplication];

    // Set up a mocked device api client
    self.mockedDeviceAPIClient = [OCMockObject partialMockForObject:[UAPush shared].deviceAPIClient];
}

- (void)tearDown {
    [super tearDown];
    [self.applicationClassMock stopMocking];
    [self.mockedApplication stopMocking];
    [self.mockedDeviceAPIClient stopMocking];
}

- (void)testParseDeviceToken {
    XCTAssertEqualObjects(@"hello", [[UAPush shared] parseDeviceToken:@"<> he<l <<<l >> o"],
                          @"parseDeviceTokens should remove all <, >, and white space from the token");

    XCTAssertNil([[UAPush shared] parseDeviceToken:nil],
                          @"parseDeviceTokens should return nil when passed nil");

    XCTAssertEqualObjects(@"", [[UAPush shared] parseDeviceToken:@""],
                 @"parseDeviceTokens should do nothing to an empty string");
}

- (void)testAutoBadgeEnabled {
    [UAPush shared].autobadgeEnabled = true;
    XCTAssertTrue([UAPush shared].autobadgeEnabled, @"autobadgeEnabled should be enabled when set to YES");
    XCTAssertTrue([[NSUserDefaults standardUserDefaults] boolForKey:UAPushBadgeSettingsKey], @"autobadgeEnabled should be stored in standardUserDefaults");

    [UAPush shared].autobadgeEnabled = NO;
    XCTAssertFalse([UAPush shared].autobadgeEnabled, @"autobadgeEnabled should be disabled when set to NO");
    XCTAssertFalse([[NSUserDefaults standardUserDefaults] boolForKey:UAPushBadgeSettingsKey], @"autobadgeEnabled should be stored in standardUserDefaults");
}

- (void)testAlias {
    [UAPush shared].alias = @"some-alias";
    XCTAssertEqualObjects(@"some-alias", [UAPush shared].alias, @"alias is not being set correctly");
    XCTAssertEqualObjects(@"some-alias", [[NSUserDefaults standardUserDefaults] stringForKey:UAPushAliasSettingsKey], @"alias should be stored in standardUserDefaults");

    [UAPush shared].alias = nil;
    XCTAssertNil([UAPush shared].alias, @"alias should be able to be cleared");
    XCTAssertNil([[NSUserDefaults standardUserDefaults] stringForKey:UAPushAliasSettingsKey], @"alias should be able to be cleared in standardUserDefaults");
}

- (void)testTags {
    NSArray *tags = @[@"tag-one", @"tag-two"];
    [UAPush shared].tags = tags;

    XCTAssertEqual(2U, [UAPush shared].tags.count, @"should of added 2 tags");
    XCTAssertEqualObjects(tags, [UAPush shared].tags, @"tags are not stored correctly");
    XCTAssertEqualObjects([[NSUserDefaults standardUserDefaults] valueForKey:UAPushTagsSettingsKey], [UAPush shared].tags, @"tags are not stored correctly in standardUserDefaults");

    [UAPush shared].tags = nil;
    XCTAssertEqual(0U, [UAPush shared].tags.count, @"tags should return an empty array even when set to nil");
    XCTAssertEqual(0U, [[[NSUserDefaults standardUserDefaults] valueForKey:UAPushTagsSettingsKey] count], @"tags are not being cleared in standardUserDefaults");
}

- (void)testAddTagsToCurrentDevice {
    [UAPush shared].tags = nil;

    [[UAPush shared] addTagsToCurrentDevice:@[@"tag-one", @"tag-two"]];
    XCTAssertEqualObjects((@[@"tag-one", @"tag-two"]), [UAPush shared].tags, @"Add tags to current device failes when no existing tags exist");

    // Try to add same tags again
    [[UAPush shared] addTagsToCurrentDevice:@[@"tag-one", @"tag-two"]];
    XCTAssertEqual(2U, [UAPush shared].tags.count, @"Add tags should not add duplicate tags");


    // Try to add a new set of tags, with one of the tags being unique
    [[UAPush shared] addTagsToCurrentDevice:@[@"tag-one", @"tag-three"]];
    XCTAssertEqual(3U, [UAPush shared].tags.count, @"Add tags should add unique tags even if some of them are duplicate");
    XCTAssertEqualObjects((@[@"tag-three", @"tag-one", @"tag-two"]), [UAPush shared].tags, @"Add tags should add unique tags even if some of them are duplicate");

    // Try to add an nil set of tags
    XCTAssertNoThrow([[UAPush shared] addTagsToCurrentDevice:nil], @"Should not throw when adding a nil set of tags");

    // Try to add an nil set of tags
    XCTAssertNoThrow([[UAPush shared] addTagsToCurrentDevice:[NSArray array]], @"Should not throw when adding an empty tag array");
}

- (void)testAddTagToCurrentDevice {
    [UAPush shared].tags = nil;

    [[UAPush shared] addTagToCurrentDevice:@"tag-one"];
    XCTAssertEqualObjects((@[@"tag-one"]), [UAPush shared].tags, @"Add tag to current device failes when no existing tags exist");

    // Try to add same tag again
    [[UAPush shared] addTagToCurrentDevice:@"tag-one"];
    XCTAssertEqual(1U, [UAPush shared].tags.count, @"Add tag should not add duplicate tags");

    // Add a new tag
    [[UAPush shared] addTagToCurrentDevice:@"tag-two"];
    XCTAssertEqualObjects((@[@"tag-one", @"tag-two"]), [UAPush shared].tags, @"Adding another tag to tags fails");

    // Try to add an nil tag
    XCTAssertThrows([[UAPush shared] addTagToCurrentDevice:nil], @"Should throw when adding a nil tag");
}

- (void)testRemoveTagFromCurrentDevice {
    [UAPush shared].tags = nil;
    XCTAssertNoThrow([[UAPush shared] removeTagFromCurrentDevice:@"some-tag"], @"Should not throw when removing a tag when tags are empty");

    [UAPush shared].tags = @[@"some-tag", @"some-other-tag"];
    XCTAssertNoThrow([[UAPush shared] removeTagFromCurrentDevice:@"some-not-found-tag"], @"Should not throw when removing a tag that does not exist");

    [[UAPush shared] removeTagFromCurrentDevice:@"some-tag"];
    XCTAssertEqualObjects((@[@"some-other-tag"]), [UAPush shared].tags, @"Remove tag from device should actually remove the tag");

    XCTAssertThrows([[UAPush shared] removeTagFromCurrentDevice:nil], @"Should throw when removing a nil tag");
}

- (void)testRemoveTagsFromCurrentDevice {
    [UAPush shared].tags = nil;
    XCTAssertNoThrow([[UAPush shared] removeTagsFromCurrentDevice:@[@"some-tag"]], @"Should not throw when removing a tags when tags are empty");

    [UAPush shared].tags = @[@"some-tag", @"some-other-tag"];
    XCTAssertNoThrow([[UAPush shared] removeTagsFromCurrentDevice:@[@"some-not-found-tag"]], @"Should not throw when removing tags that do not exist");

    [[UAPush shared] removeTagsFromCurrentDevice:@[@"some-tag"]];
    XCTAssertEqualObjects((@[@"some-other-tag"]), [UAPush shared].tags, @"Remove tags from device should actually remove the tag");

    XCTAssertNoThrow([[UAPush shared] removeTagsFromCurrentDevice:nil], @"Should throw when removing a nil set of tags");
}

- (void)testPushEnabledToYes {
    [UAPush shared].pushEnabled = NO;

    // Make sure push is set to NO
    XCTAssertFalse([UAPush shared].pushEnabled, @"pushEnabled should default to NO");

    // Set the notificationTypes so we know what to expect when it registers
    [UAPush shared].notificationTypes = UIRemoteNotificationTypeAlert;

    [[self.mockedApplication expect] registerForRemoteNotificationTypes:UIRemoteNotificationTypeAlert];

    [UAPush shared].pushEnabled = YES;

    XCTAssertTrue([UAPush shared].pushEnabled, @"pushEnabled should be enabled when set to YES");
    XCTAssertTrue([[NSUserDefaults standardUserDefaults] boolForKey:UAPushEnabledSettingsKey], @"pushEnabled should be stored in standardUserDefaults");
    XCTAssertNoThrow([self.mockedApplication verify], @"pushEnabled should register for remote notifications");
}

- (void)testPushEnabledToNo {
    [UAPush shared].deviceToken = @"sometoken";
    [UAPush shared].pushEnabled = YES;

    // Add a device token so we get a device api callback
    [[self.mockedDeviceAPIClient expect] unregisterWithData:OCMOCK_ANY onSuccess:OCMOCK_ANY onFailure:OCMOCK_ANY forcefully:NO];
    [[self.mockedApplication expect] registerForRemoteNotificationTypes:UIRemoteNotificationTypeNone];

    [UAPush shared].pushEnabled = NO;

    XCTAssertFalse([UAPush shared].pushEnabled, @"pushEnabled should be disabled when set to NO");
    XCTAssertFalse([[NSUserDefaults standardUserDefaults] boolForKey:UAPushEnabledSettingsKey], @"pushEnabled should be stored in standardUserDefaults");
    XCTAssertNoThrow([self.mockedApplication verify], @"pushEnabled should unregister for remote notifications");

    XCTAssertNoThrow([self.mockedDeviceAPIClient verify], @"pushEnabled should make unregister with the device api client");
}

- (void)testSetQuiteTimeFromTo {
    NSDate *start = [NSDate dateWithTimeIntervalSince1970:60]; // 0:01 GMT
    NSDate *end = [NSDate dateWithTimeIntervalSince1970:60 * 60 * 13]; // 13:00 GMT

    [[UAPush shared] setQuietTimeFrom:start to:end withTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"]];
    XCTAssertEqualObjects(@"GMT", [[UAPush shared].timeZone abbreviation], @"Timezone should be set to the timezone in quiet time");

    NSDictionary *quietTime = [UAPush shared].quietTime;
    XCTAssertEqualObjects(@"0:01", [quietTime valueForKey:UAPushQuietTimeStartKey], @"Quiet time start is not set correctly");
    XCTAssertEqualObjects(@"13:00", [quietTime valueForKey:UAPushQuietTimeEndKey], @"Quiet time end is not set correctly");


    //Test setting timezone to CDT to make sure hours are -5 GMT
    [[UAPush shared] setQuietTimeFrom:start to:end withTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"CDT"]];
    XCTAssertEqualObjects(@"CDT", [[UAPush shared].timeZone abbreviation], @"Timezone should be set to the timezone in quiet time");

    quietTime = [UAPush shared].quietTime;
    XCTAssertEqualObjects(@"18:01", [quietTime valueForKey:UAPushQuietTimeStartKey], @"Quiet time start is not set handling timezone correctly");
    XCTAssertEqualObjects(@"7:00", [quietTime valueForKey:UAPushQuietTimeEndKey], @"Quiet time end is not set handling timezone correctly");
}

- (void)testSetQuiteTimeFromToNoTimeZone {
    NSDate *start = [NSDate dateWithTimeIntervalSince1970:60]; // 0:01 GMT
    NSDate *end = [NSDate dateWithTimeIntervalSince1970:60 * 60 * 13]; // 13:00 GMT

    // Set the current timezone to CDT
    [UAPush shared].timeZone = [NSTimeZone timeZoneWithAbbreviation:@"CDT"];

    // When timezone is nil, it uses whatever defaultQuietTimeZone is, then sets it to timezone
    [[UAPush shared] setQuietTimeFrom:start to:end withTimeZone:nil];

    XCTAssertEqualObjects([[UAPush shared].defaultTimeZoneForQuietTime abbreviation], [[UAPush shared].timeZone abbreviation], @"Timezone should be set to defaultTimeZoneForQuietTime");
}

- (void)testTimeZone {
    [UAPush shared].timeZone = [NSTimeZone timeZoneWithAbbreviation:@"EST"];

    XCTAssertEqualObjects([NSTimeZone timeZoneWithAbbreviation:@"EST"], [UAPush shared].timeZone, @"timezone is not being set correctly");
    XCTAssertEqualObjects([[NSTimeZone timeZoneWithAbbreviation:@"EST"] name], [[NSUserDefaults standardUserDefaults] stringForKey:UAPushTimeZoneSettingsKey], @"timezone should be stored in standardUserDefaults");

    [UAPush shared].timeZone = nil;
    XCTAssertNil([UAPush shared].timeZone, @"timezone should be able to be cleared");
    XCTAssertNil([[NSUserDefaults standardUserDefaults] stringForKey:UAPushTimeZoneSettingsKey], @"timezone should be able to be cleared in standardUserDefaults");
}

- (void)testRegisterFroRemoteNotificationsPushEnabled {
    [UAPush shared].pushEnabled = YES;
    [UAPush shared].notificationTypes = UIRemoteNotificationTypeSound;

    [[self.mockedApplication expect] registerForRemoteNotificationTypes:UIRemoteNotificationTypeSound];
    [[UAPush shared] registerForRemoteNotifications];

    XCTAssertNoThrow([self.mockedApplication verify], @"should register for push notification types when push is enabled");

}

- (void)testRegisterFroRemoteNotificationsPushDisabled {
    [UAPush shared].pushEnabled = NO;
    [UAPush shared].notificationTypes = UIRemoteNotificationTypeSound;

    [[self.mockedApplication reject] registerForRemoteNotificationTypes:UIRemoteNotificationTypeSound];
    [[UAPush shared] registerForRemoteNotifications];

    XCTAssertNoThrow([self.mockedApplication verify], @"should not register for push notification types when push is enabled");
}

- (void)testRegisterFroRemoteNotificationTypesPushEnabled {
    [UAPush shared].pushEnabled = YES;
    [UAPush shared].notificationTypes = UIRemoteNotificationTypeSound;

    [[self.mockedApplication expect] registerForRemoteNotificationTypes:UIRemoteNotificationTypeBadge];
    [[UAPush shared] registerForRemoteNotificationTypes:UIRemoteNotificationTypeBadge];

    XCTAssertNoThrow([self.mockedApplication verify], @"should register for push notification types when push is enabled");
    XCTAssertEqual(UIRemoteNotificationTypeBadge, [UAPush shared].notificationTypes, @"registerForPushNotificationTypes should still set the notificationTypes when push is disabled");
}

- (void)testRegisterFroRemoteNotificationTypesPushDisabled {
    [UAPush shared].notificationTypes = UIRemoteNotificationTypeSound;
    [UAPush shared].pushEnabled = NO;

    [[self.mockedApplication reject] registerForRemoteNotificationTypes:UIRemoteNotificationTypeBadge];
    [[UAPush shared] registerForRemoteNotificationTypes:UIRemoteNotificationTypeBadge];

    XCTAssertNoThrow([self.mockedApplication verify], @"should not register for push notification types when push is disabled");
    XCTAssertEqual(UIRemoteNotificationTypeBadge, [UAPush shared].notificationTypes, @"registerForPushNotificationTypes should still set the notificationTypes when push is disabled");
}

- (void)testSetBadgeNumber {

}

- (void)testResetBadge {

}

- (void)testRegisterDeviceToken {

}

- (void)testRegisterNSUserDefaults {

}

- (void)testsetDefaultPushEnabledValue {

}


@end
