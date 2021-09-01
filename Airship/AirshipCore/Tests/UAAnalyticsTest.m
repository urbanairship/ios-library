/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"

#import "UAEvent.h"
#import "UAirship+Internal.h"

#import "AirshipTests-Swift.h"

@import AirshipCore;

@interface UAAnalytics()
- (void)onEnabledFeaturesChanged;
@end

@interface UAPrivacyManager()
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@end

@interface UAAnalyticsTest: UAAirshipBaseTest
@property (nonatomic, strong) UAAnalytics *analytics;
@property (nonatomic, strong) UAPrivacyManager *privacyManager;
@property (nonatomic, strong) id mockEventManager;
@property (nonatomic, strong) id mockChannel;
@property (nonatomic, strong) id mockLocaleClass;
@property (nonatomic, strong) id mockTimeZoneClass;
@property (nonatomic, strong) UATestAppStateTracker *testAppStateTracker;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@property (nonatomic, strong) UATestDate *testDate;
@property (nonatomic, strong) id<UAEventManagerDelegate> eventManagerDelegate;
@end

@implementation UAAnalyticsTest

- (void)setUp {
    [super setUp];


    self.notificationCenter = [[NSNotificationCenter alloc] init];
    self.testDate = [[UATestDate alloc] init];
    self.mockEventManager = [self mockForProtocol:@protocol(UAEventManagerProtocol)];
    [[[self.mockEventManager stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        self.eventManagerDelegate =  (__bridge id<UAEventManagerDelegate>)arg;
    }] setDelegate:OCMOCK_ANY];

    // Locale
    self.mockLocaleClass = [self mockForClass:[UALocaleManager class]];
    NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    [[[self.mockLocaleClass stub] andReturn:locale] currentLocale];
    
    self.mockChannel = [self mockForClass:[UAChannel class]];
    self.testAppStateTracker = [[UATestAppStateTracker alloc] init];

    self.privacyManager = [[UAPrivacyManager alloc] initWithDataStore:self.dataStore defaultEnabledFeatures:UAFeaturesAll notificationCenter:self.notificationCenter];
    
    self.analytics = [self createAnalytics];
    
    // Channel ID
    NSString *channelIDString = @"someChannelID";
    [[[self.mockChannel stub] andReturn:channelIDString] identifier];

    // Timezone
    self.mockTimeZoneClass = [self strictMockForClass:[NSTimeZone class]];
    NSTimeZone *timeZone = [[NSTimeZone alloc] initWithName:@"America/New_York"];
    [[[self.mockTimeZoneClass stub] andReturn:timeZone] defaultTimeZone];
}

- (void)tearDown {
    [self.mockTimeZoneClass stopMocking];
    [super tearDown];
}

- (void)testBackgroundInitEmitsAppInitEvent {
    self.testAppStateTracker.currentState = UAApplicationStateBackground;

    [[self.mockEventManager expect] add:[OCMArg checkWithBlock:^BOOL(id obj) {
        return [obj isMemberOfClass:[UAAppInitEvent class]];
    }] eventID:OCMOCK_ANY eventDate:OCMOCK_ANY sessionID:OCMOCK_ANY];

    [self createAnalytics];
    [self.mockEventManager verify];
}

- (void)testInactiveInitDoesNotEmitEvents {
    self.testAppStateTracker.currentState = UAApplicationStateInactive;

    [[self.mockEventManager reject] add:OCMOCK_ANY eventID:OCMOCK_ANY eventDate:OCMOCK_ANY sessionID:OCMOCK_ANY];

    [self createAnalytics];
    [self.mockEventManager verify];
}

- (void)testFirstTransitionToForegroundEmitsAppInit {
    // Create analytics in inactive state so that init is deferred
    self.testAppStateTracker.currentState = UAApplicationStateInactive;

    [self createAnalytics];

    [[self.mockEventManager expect] add:[OCMArg checkWithBlock:^BOOL(id obj) {
        return [obj isMemberOfClass:[UAAppInitEvent class]];
    }] eventID:OCMOCK_ANY eventDate:OCMOCK_ANY sessionID:OCMOCK_ANY];

    [[self.mockEventManager reject] add:[OCMArg checkWithBlock:^BOOL(id obj) {
        return [obj isMemberOfClass:[UAAppForegroundEvent class]];
    }] eventID:OCMOCK_ANY eventDate:OCMOCK_ANY sessionID:OCMOCK_ANY];

    [self.notificationCenter postNotificationName:UAAppStateTracker.didTransitionToForeground object:nil];

    [self.mockEventManager verify];
}

- (void)testSubsequentTransitionToForegroundEmitsForegroundEvent {
    [[self.mockEventManager expect] add:[OCMArg checkWithBlock:^BOOL(id obj) {
        return [obj isMemberOfClass:[UAAppForegroundEvent class]];
    }] eventID:OCMOCK_ANY eventDate:OCMOCK_ANY sessionID:OCMOCK_ANY];

    [self.notificationCenter postNotificationName:UAAppStateTracker.didTransitionToForeground object:nil];
    [self.notificationCenter postNotificationName:UAAppStateTracker.didTransitionToForeground object:nil];


    [self.mockEventManager verify];
}

- (void)testBackgroundBeforeForegroundEmitsAppInit {
    // Create analytics in inactive state so that init is deferred
    self.testAppStateTracker.currentState = UAApplicationStateInactive;

    [self createAnalytics];

    [[self.mockEventManager expect] add:[OCMArg checkWithBlock:^BOOL(id obj) {
        return [obj isMemberOfClass:[UAAppInitEvent class]];
    }] eventID:OCMOCK_ANY eventDate:OCMOCK_ANY sessionID:OCMOCK_ANY];

    [[self.mockEventManager expect] add:[OCMArg checkWithBlock:^BOOL(id obj) {
        return [obj isMemberOfClass:[UAAppBackgroundEvent class]];
    }] eventID:OCMOCK_ANY eventDate:OCMOCK_ANY sessionID:OCMOCK_ANY];

    [self.notificationCenter postNotificationName:UAAppStateTracker.didEnterBackgroundNotification object:nil];

    [self.mockEventManager verify];
}

- (void)testBackgroundAfterForegroundDoesNotEmitAppInit {
    [self.notificationCenter postNotificationName:UAAppStateTracker.didTransitionToForeground object:nil];

    [[self.mockEventManager reject] add:[OCMArg checkWithBlock:^BOOL(id obj) {
        return [obj isMemberOfClass:[UAAppInitEvent class]];
    }] eventID:OCMOCK_ANY eventDate:OCMOCK_ANY sessionID:OCMOCK_ANY];

    [[self.mockEventManager expect] add:[OCMArg checkWithBlock:^BOOL(id obj) {
        return [obj isMemberOfClass:[UAAppBackgroundEvent class]];
    }] eventID:OCMOCK_ANY eventDate:OCMOCK_ANY sessionID:OCMOCK_ANY];

    [self.notificationCenter postNotificationName:UAAppStateTracker.didEnterBackgroundNotification object:nil];

    [self.mockEventManager verify];
}

/**
 * Test disabling analytics will result in deleting the database.
 */
- (void)testDisablingAnalytics {
    [self.privacyManager enableFeatures:UAFeaturesAnalytics];
    [[self.mockEventManager expect] setUploadsEnabled:NO];
    [[self.mockEventManager expect] deleteAllEvents];
    [self.privacyManager disableFeatures:UAFeaturesAnalytics];


    [self.mockEventManager verify];
    XCTAssertFalse([self.privacyManager isEnabled:UAFeaturesAnalytics]);
}

/**
 * Tests adding an invalid event.
 * Expects adding an invalid event drops the event.
 */
- (void)testAddInvalidEvent {
    // Mock invalid event
    id mockEvent = [self mockForProtocol:@protocol(UAEvent)];
    [[[mockEvent stub] andReturnValue:OCMOCK_VALUE(NO)] isValid];

    // Ensure event add is never attempted
    [[self.mockEventManager reject] add:mockEvent eventID:OCMOCK_ANY eventDate:OCMOCK_ANY sessionID:OCMOCK_ANY];

    // Add invalid event
    [self.analytics addEvent:mockEvent];

    [self.mockEventManager  verify];
    [mockEvent stopMocking];
}

/**
 * Tests adding a valid event.
 * Expects adding a valid event succeeds and increases database size.
 */
- (void)testAddEvent {
    // Mock valid event
    id mockEvent = [self mockForProtocol:@protocol(UAEvent)];
    [[[mockEvent stub] andReturnValue:OCMOCK_VALUE(YES)] isValid];

    // Ensure event is added
    XCTestExpectation *eventAdded = [self expectationWithDescription:@"Notification event added"];
    [[[self.mockEventManager expect] andDo:^(NSInvocation *invocation) {
        [eventAdded fulfill];
    }] add:mockEvent eventID:OCMOCK_ANY eventDate:OCMOCK_ANY sessionID:OCMOCK_ANY];


    // Add valid event
    [self.analytics addEvent:mockEvent];

    [self waitForTestExpectations];
    [self.mockEventManager verify];
    [mockEvent stopMocking];
}

/**
 * Tests adding a valid event when analytics is disabled.
 * Expects adding a valid event when analytics is disabled drops event.
 */
- (void)testAddEventAnalyticsDisabled {
    [self.privacyManager disableFeatures:UAFeaturesAnalytics];

    // Mock valid event
    id mockEvent = [self mockForProtocol:@protocol(UAEvent)];
    [[[mockEvent stub] andReturnValue:OCMOCK_VALUE(YES)] isValid];

    // Ensure event add is never attempted
    [[self.mockEventManager reject] add:mockEvent eventID:OCMOCK_ANY eventDate:OCMOCK_ANY sessionID:OCMOCK_ANY];

    // Add valid event
    [self.analytics addEvent:mockEvent];

    [self.mockEventManager verify];
    [mockEvent stopMocking];
}

/**
 * Test associateIdentifiers: adds an UAAssociateIdentifiersEvent with the
 * expected identifiers.
 */
- (void)testAssociateDeviceIdentifiers {

    NSDictionary *identifiers = @{@"some identifier": @"some value"};
    XCTestExpectation *eventAdded = [self expectationWithDescription:@"Notification event added"];
    [[[self.mockEventManager expect] andDo:^(NSInvocation *invocation) {
        [eventAdded fulfill];
    }] add:[OCMArg checkWithBlock:^BOOL(id obj) {
        if (![obj isKindOfClass:[UAAssociateIdentifiersEvent class]]) {
            return NO;
        }

        UAAssociateIdentifiersEvent *event = obj;
        return [event.data isEqualToDictionary:identifiers];
    }] eventID:OCMOCK_ANY eventDate:OCMOCK_ANY sessionID:OCMOCK_ANY];

    // Associate the identifiers
    [self.analytics associateDeviceIdentifiers:[UAAssociatedIdentifiers identifiersWithDictionary:identifiers]];

    [self waitForTestExpectations];
    XCTAssertEqualObjects(identifiers, [self.analytics currentAssociatedDeviceIdentifiers].allIDs, @"DeviceIdentifiers should match");

    // Verify the event was added
    [self.mockEventManager verify];
}

/**
 * Test associateIdentifiers does nothing if data collection is disabled.
 */
- (void)testAssociateDeviceIdentifiersDataCollectionDisabled {
    [self.privacyManager disableFeatures:UAFeaturesAnalytics];

    NSDictionary *identifiers = @{@"some identifier": @"some value"};

    // Associate the identifiers
    [self.analytics associateDeviceIdentifiers:[UAAssociatedIdentifiers identifiersWithDictionary:identifiers]];

    XCTAssertEqualObjects(@{}, [self.analytics currentAssociatedDeviceIdentifiers].allIDs, @"Device identifiers should be empty");
}

/**
 * Test associate duplicate identifiers: associates a duplicate identifier
 * and ensures event is only added once.
 */
- (void)testDuplicateAssociateDeviceIdentifiers {
    NSDictionary *identifiers = @{@"some identifier": @"some value"};
    XCTestExpectation *eventAdded = [self expectationWithDescription:@"Event added"];
    [[[self.mockEventManager expect] andDo:^(NSInvocation *invocation) {
        [eventAdded fulfill];
    }] add:[OCMArg checkWithBlock:^BOOL(id obj) {
        if (![obj isKindOfClass:[UAAssociateIdentifiersEvent class]]) {
            return NO;
        }

        UAAssociateIdentifiersEvent *event = obj;
        return [event.data isEqualToDictionary:identifiers];
    }] eventID:OCMOCK_ANY eventDate:OCMOCK_ANY sessionID:OCMOCK_ANY];

    // Associate the identifiers
    [self.analytics associateDeviceIdentifiers:[UAAssociatedIdentifiers identifiersWithDictionary:identifiers]];

    [self waitForTestExpectations];

    // Reject duplicate call
    [[self.mockEventManager reject] add:OCMOCK_ANY eventID:OCMOCK_ANY eventDate:OCMOCK_ANY sessionID:OCMOCK_ANY];

    // Associate the duplicate identifiers
    [self.analytics associateDeviceIdentifiers:[UAAssociatedIdentifiers identifiersWithDictionary:identifiers]];

    // Verify first event was added and duplicate was rejected
    [self.mockEventManager verify];
}

/**
 * Test a MISSING_SEND_ID string is sent when the conversionSendID is missing.
 */
- (void)testMissingSendID {
    NSDictionary *notification = @{
                                   @"aps": @{
                                           @"alert": @"sample alert!"
                                           }
                                   };

    [self.analytics launchedFromNotification:notification];

    XCTAssertEqualObjects(@"MISSING_SEND_ID", self.analytics.conversionSendID, @"ConversionSendID should be MISSING_SEND_ID");
}

/**
 * Test the conversionPushMetadata is sent.
 */
- (void)testConversionPushMetadata {
    NSDictionary *notification = @{
                                   @"aps": @{
                                           @"alert": @"sample alert!"
                                           },
                                   @"com.urbanairship.metadata": @"THE_BASE64_METADATA_STRING"
                                   };

    [self.analytics launchedFromNotification:notification];

    XCTAssertEqualObjects(@"MISSING_SEND_ID", self.analytics.conversionSendID, @"ConversionSendID should be MISSING_SEND_ID");
    XCTAssertEqualObjects(@"THE_BASE64_METADATA_STRING", self.analytics.conversionPushMetadata, @"ConversionPushMetadata should be set");
}

/**
 * Test conversionPushMetadata is nil when it is missing from the payload.
 */
- (void)testMissingConversionPushMetadata {
    NSDictionary *notification = @{
                                   @"aps": @{
                                           @"alert": @"sample alert!"
                                           }
                                   };

    [self.analytics launchedFromNotification:notification];

    XCTAssertEqualObjects(@"MISSING_SEND_ID", self.analytics.conversionSendID, @"ConversionSendID should be MISSING_SEND_ID");
    XCTAssertNil(self.analytics.conversionPushMetadata, @"ConversionPushMetadata should be nil if missing.");
}

- (void)testLaunchedFromNotificationSilentPush {
    NSDictionary *notification = @{
        @"aps": @{
        },
        @"com.urbanairship.metadata": @"THE_BASE64_METADATA_STRING"
    };

    [self.analytics launchedFromNotification:notification];

    XCTAssertNil(self.analytics.conversionSendID);
    XCTAssertNil(self.analytics.conversionPushMetadata);
}

/**
 * Test that tracking event adds itself on background
 */
- (void)testTrackingEventBackground{
    [self.analytics trackScreen:@"test_screen"];

    // Expect that the event is added to the mock DB Manager upon background
    XCTestExpectation *eventAdded = [self expectationWithDescription:@"Notification event added"];
    [[[self.mockEventManager expect] andDo:^(NSInvocation *invocation) {
        [eventAdded fulfill];
    }] add:[OCMArg checkWithBlock:^BOOL(id obj) {
        if (![obj isKindOfClass:[UAScreenTrackingEvent class]]) {
            return NO;
        }

        UAScreenTrackingEvent *event = obj;

        return [event.screen isEqualToString:@"test_screen"];
    }] eventID:OCMOCK_ANY eventDate:OCMOCK_ANY sessionID:OCMOCK_ANY];

    // Background
    [self.notificationCenter postNotificationName:UAAppStateTracker.didEnterBackgroundNotification
                                           object:nil];

    [self waitForTestExpectations];

    [self.mockEventManager verify];
}

/**
 * Test tracking event adds itself and is set to nil on terminate event.
 */
- (void)testTrackingEventTerminate {

    [self.analytics trackScreen:@"test_screen"];

    // Expect that the event is added to the mock DB Manager upon terminate
    XCTestExpectation *eventAdded = [self expectationWithDescription:@"Notification event added"];
    [[[self.mockEventManager expect] andDo:^(NSInvocation *invocation) {
        [eventAdded fulfill];
    }] add:[OCMArg checkWithBlock:^BOOL(id obj) {
        if (![obj isKindOfClass:[UAScreenTrackingEvent class]]) {
            return NO;
        }

        UAScreenTrackingEvent *event = obj;

        return [event.screen isEqualToString:@"test_screen"];
    }] eventID:OCMOCK_ANY eventDate:OCMOCK_ANY sessionID:OCMOCK_ANY];

    // Terminate
    [self.notificationCenter postNotificationName:UAAppStateTracker.willTerminateNotification object:nil];

    [self waitForTestExpectations];

    [self.mockEventManager verify];
}

// Tests that starting a screen tracking event when one is already started adds the event with the correct start and stop times
- (void)testStartTrackScreenAddEvent {

    self.testDate.dateOverride = [NSDate dateWithTimeIntervalSince1970:0];
    [self.analytics trackScreen:@"first_screen"];

    // Expect that the mock event is added to the mock DB Manager
    XCTestExpectation *eventAdded = [self expectationWithDescription:@"Notification event added"];
    [[[self.mockEventManager expect] andDo:^(NSInvocation *invocation) {
        [eventAdded fulfill];
    }] add:[OCMArg checkWithBlock:^BOOL(id obj) {
        if (![obj isKindOfClass:[UAScreenTrackingEvent class]]) {
            return NO;
        }

        UAScreenTrackingEvent *event = obj;

        XCTAssertEqualWithAccuracy(event.startTime, 0, 1);
        XCTAssertEqualWithAccuracy(event.stopTime, 20, 1);

        return [event.screen isEqualToString:@"first_screen"];
    }] eventID:OCMOCK_ANY eventDate:OCMOCK_ANY sessionID:OCMOCK_ANY];

    self.testDate.offset = 20;

    [self.analytics trackScreen:@"second_screen"];

    [self waitForTestExpectations];

    [self.mockEventManager verify];
}

// Tests forwarding screens to the analytics delegate.
- (void)testForwardScreenTracks {
    __block id event;
    XCTestExpectation *notificationFired = [self expectationWithDescription:@"Notification event fired"];
    [self.notificationCenter addObserverForName:UAAnalytics.screenTracked object:nil queue:nil usingBlock:^(NSNotification *note) {
        event = note.userInfo;
        [notificationFired fulfill];
    }];

    [self.analytics trackScreen:@"screen"];

    [self waitForTestExpectations];

    id expectedEvent = @{ @"screen": @"screen"};
    XCTAssertEqualObjects(expectedEvent, event);
}

// Tests forwarding region events to the analytics delegate.
- (void)testForwardRegionEvents {
    XCTestExpectation *notificationFired = [self expectationWithDescription:@"Notification event fired"];

    [self.notificationCenter addObserverForName:UAAnalytics.regionEventAdded object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        [notificationFired fulfill];
    }];

    UARegionEvent *regionEnter = [UARegionEvent regionEventWithRegionID:@"region" source:@"test" boundaryEvent:UABoundaryEventEnter];
    [self.analytics addEvent:regionEnter];

    [self waitForTestExpectations];
}

// Tests forwarding custom events to the analytics delegate.
- (void)testForwardCustomEvents {
    XCTestExpectation *notificationFired = [self expectationWithDescription:@"Notification event fired"];

    [self.notificationCenter addObserverForName:UAAnalytics.customEventAdded object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        [notificationFired fulfill];
    }];

    UACustomEvent *purchase = [UACustomEvent eventWithName:@"purchase" value:@(100)];
    [self.analytics addEvent:purchase];

    [self waitForTestExpectations];
}

// Test disabling / enabling the analytics component disables / enables eventmanager uploads
- (void)testComponentEnabledSwitch {
    self.analytics.componentEnabled = YES;
    [self.privacyManager enableFeatures:UAFeaturesAnalytics];

    // expectations
    [[self.mockEventManager expect] setUploadsEnabled:NO];

    // test
    self.analytics.componentEnabled = NO;

    // verify
    [self.mockEventManager verify];

    // expectations
    [[self.mockEventManager expect] setUploadsEnabled:YES];
    [[self.mockEventManager expect] scheduleUpload];

    // test
    self.analytics.componentEnabled = YES;

    // verify
    [self.mockEventManager verify];
}

- (void)testAnalyticsHeadersSDKExtensions {
    [self.analytics registerSDKExtension:UASDKExtensionCordova version:@"1.2.3"];
    [self.analytics registerSDKExtension:UASDKExtensionUnity version:@"5,.6,.7,,,"];

    id headers = [self.eventManagerDelegate analyticsHeaders];
    XCTAssertEqualObjects(@"cordova:1.2.3, unity:5.6.7", headers[@"X-UA-Frameworks"]);
}

- (void)testAnalyticsHeaders {
    id headers = [self.eventManagerDelegate analyticsHeaders];
    id expected = @{
        @"X-UA-Channel-ID": @"someChannelID",
        @"X-UA-Timezone": @"America/New_York",
        @"X-UA-Locale-Language": @"en",
        @"X-UA-Locale-Country": @"US",
        @"X-UA-Locale-Variant": @"POSIX",
        @"X-UA-Device-Family": [UIDevice currentDevice].systemName,
        @"X-UA-OS-Version": [UIDevice currentDevice].systemVersion,
        @"X-UA-Device-Model": [UAUtils deviceModelName],
        @"X-UA-Lib-Version": [UAirshipVersion get],
        @"X-UA-App-Key": self.config.appKey,
        @"X-UA-Package-Name": [[[NSBundle mainBundle] infoDictionary] objectForKey:(id)kCFBundleIdentifierKey],
        @"X-UA-Package-Version": [UAUtils bundleShortVersionString] ?: @""
    };

    XCTAssertEqualObjects(expected, headers);
}

- (void)testAnalyticsHeadersBlock {
    [self.analytics addAnalyticsHeadersBlock:^NSDictionary<NSString *,NSString *> * _Nullable{
        return @{@"cool" : @"story"};
    }];

    id headers = [self.eventManagerDelegate analyticsHeaders];
    XCTAssertEqualObjects(@"story", headers[@"cool"]);
}

- (void)testOnDataCollectionDisabled {
    self.analytics.componentEnabled = YES;
    [self.privacyManager enableFeatures:UAFeaturesAnalytics];

    NSDictionary *identifiers = @{@"some identifier": @"some value"};

    // Associate the identifiers
    [self.analytics associateDeviceIdentifiers:[UAAssociatedIdentifiers identifiersWithDictionary:identifiers]];

    XCTAssertEqualObjects(self.analytics.currentAssociatedDeviceIdentifiers.allIDs, identifiers);

    [[self.mockEventManager expect] setUploadsEnabled:NO];
    [[self.mockEventManager expect] deleteAllEvents];

    [self.privacyManager disableFeatures:UAFeaturesAnalytics];
    [self.analytics onEnabledFeaturesChanged];

    [self.mockEventManager verify];

    XCTAssertEqualObjects(self.analytics.currentAssociatedDeviceIdentifiers.allIDs, @{});
}

- (void)testOnDataCollectionEnabled {
    [[self.mockEventManager expect] setUploadsEnabled:YES];

    [self.privacyManager enableFeatures:UAFeaturesAnalytics];
    [self.analytics onEnabledFeaturesChanged];

    [self.mockEventManager verify];
}

- (void)testBackgroundEventSessionID {
    UAAnalytics *analytics = [[UAAnalytics alloc] initWithConfig:self.config
                                                       dataStore:self.dataStore
                                                         channel:self.mockChannel
                                                    eventManager:self.mockEventManager
                                              notificationCenter:self.notificationCenter
                                                            date:self.testDate
                                                      dispatcher:UADispatcher.main
                                                   localeManager:self.mockLocaleClass
                                                 appStateTracker:self.testAppStateTracker
                                                  privacyManager:self.privacyManager];

    NSString *sessionID = analytics.sessionID;

    // Ensure event is added
    XCTestExpectation *eventAdded = [self expectationWithDescription:@"Notification event added"];
    [[[self.mockEventManager expect] andDo:^(NSInvocation *invocation) {
        [eventAdded fulfill];
    }] add:OCMOCK_ANY eventID:OCMOCK_ANY eventDate:OCMOCK_ANY sessionID:sessionID];

    // Background app
    [self.notificationCenter postNotificationName:UAAppStateTracker.didEnterBackgroundNotification object:nil];

    [self waitForTestExpectations];
    [self.mockEventManager verify];
}

- (UAAnalytics *)createAnalytics {
    return [[UAAnalytics alloc] initWithConfig:self.config
                                     dataStore:self.dataStore
                                       channel:self.mockChannel
                                  eventManager:self.mockEventManager
                            notificationCenter:self.notificationCenter
                                          date:self.testDate
                                    dispatcher:[[UATestDispatcher alloc] init]
                                 localeManager:self.mockLocaleClass
                               appStateTracker:self.testAppStateTracker
                                privacyManager:self.privacyManager];
}

@end
