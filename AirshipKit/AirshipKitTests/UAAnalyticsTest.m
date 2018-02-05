/* Copyright 2018 Urban Airship and Contributors */

#import "UABaseTest.h"

#import "UAAnalytics+Internal.h"
#import "UAConfig.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAEvent.h"
#import "UAAssociateIdentifiersEvent+Internal.h"
#import "UAScreenTrackingEvent+Internal.h"
#import "UARegionEvent.h"
#import "UACustomEvent.h"
#import "UAEventManager+Internal.h"

@interface UAAnalyticsTest: UABaseTest
@property (nonatomic, strong) UAAnalytics *analytics;
@property (nonatomic, strong) id mockEventManager;
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@end

@implementation UAAnalyticsTest

- (void)setUp {
    [super setUp];
    
    self.dataStore = [UAPreferenceDataStore preferenceDataStoreWithKeyPrefix:[NSString stringWithFormat:@"uaanalytics.test.%@",self.name]];
    [self.dataStore removeAll];
    
    self.mockEventManager = [self mockForClass:[UAEventManager class]];

    UAConfig *config = [[UAConfig alloc] init];
    self.analytics = [UAAnalytics analyticsWithConfig:config dataStore:self.dataStore eventManager:self.mockEventManager];
 }

- (void)tearDown {
    [self.dataStore removeAll];
    [self.mockEventManager stopMocking];

    [super tearDown];
}

/**
 * Test disabling analytics will result in deleting the database.
 */
- (void)testDisablingAnalytics {
    [[self.mockEventManager expect] deleteAllEvents];
    self.analytics.enabled = NO;

    [self.mockEventManager verify];
    XCTAssertFalse(self.analytics.enabled);
}

/**
 * Test the default value of enabled is YES and will not reset the value to YES
 * on init if its set to NO.
 */
- (void)testDefaultAnalyticsEnableValue {
    XCTAssertTrue(self.analytics.enabled);
    self.analytics.enabled = NO;

    // Recreate analytics and see if its still disabled
    self.analytics = [UAAnalytics analyticsWithConfig:[UAConfig config] dataStore:self.dataStore eventManager:self.mockEventManager];

    XCTAssertFalse(self.analytics.enabled);
}

/**
 * Test isEnabled always returns YES only if UAConfig enables analytics and the
 * runtime setting is enabled.
 */
- (void)testIsEnabled {
    self.analytics.enabled = YES;
    XCTAssertTrue(self.analytics.enabled);

    self.analytics.enabled = NO;
    XCTAssertFalse(self.analytics.enabled);
}

/**
 * Test isEnabled only returns NO when UAConfig disables analytics.
 */
- (void)testIsEnabledConfigOverride {
    UAConfig *config = [UAConfig config];
    config.analyticsEnabled = NO;
    self.analytics = [UAAnalytics analyticsWithConfig:config dataStore:self.dataStore eventManager:self.mockEventManager];

    self.analytics.enabled = YES;
    XCTAssertFalse(self.analytics.enabled);

    self.analytics.enabled = NO;
    XCTAssertFalse(self.analytics.enabled);
}

/**
 * Tests adding an invalid event.
 * Expects adding an invalid event drops the event.
 */
- (void)testAddInvalidEvent {
    // Mock invalid event
    id mockEvent = [self mockForClass:[UAEvent class]];
    [[[mockEvent stub] andReturnValue:OCMOCK_VALUE(NO)] isValid];

    // Ensure event add is never attempted
    [[self.mockEventManager reject] addEvent:mockEvent sessionID:OCMOCK_ANY];

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
    id mockEvent = [self mockForClass:[UAEvent class]];
    [[[mockEvent stub] andReturnValue:OCMOCK_VALUE(YES)] isValid];

    // Ensure event is added
    XCTestExpectation *eventAdded = [self expectationWithDescription:@"Notification event added"];
    [[[self.mockEventManager expect] andDo:^(NSInvocation *invocation) {
        [eventAdded fulfill];
    }] addEvent:mockEvent sessionID:OCMOCK_ANY];


    // Add valid event
    [self.analytics addEvent:mockEvent];

    [self waitForExpectationsWithTimeout:1 handler:nil];
    [self.mockEventManager verify];
    [mockEvent stopMocking];
}

/**
 * Tests adding a valid event when analytics is disabled.
 * Expects adding a valid event when analytics is disabled drops event.
 */
- (void)testAddEventAnalyticsDisabled {
    self.analytics.enabled = NO;

    // Mock valid event
    id mockEvent = [self mockForClass:[UAEvent class]];
    [[[mockEvent stub] andReturnValue:OCMOCK_VALUE(YES)] isValid];

    // Ensure event add is never attempted
    [[self.mockEventManager reject] addEvent:mockEvent sessionID:OCMOCK_ANY];

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

    NSDictionary *identifiers = @{@"some identifer": @"some value"};
    XCTestExpectation *eventAdded = [self expectationWithDescription:@"Notification event added"];
    [[[self.mockEventManager expect] andDo:^(NSInvocation *invocation) {
        [eventAdded fulfill];
    }] addEvent:[OCMArg checkWithBlock:^BOOL(id obj) {
        if (![obj isKindOfClass:[UAAssociateIdentifiersEvent class]]) {
            return NO;
        }

        UAAssociateIdentifiersEvent *event = obj;
        return [event.data isEqualToDictionary:identifiers];
    }] sessionID:OCMOCK_ANY];

    // Associate the identifiers
    [self.analytics associateDeviceIdentifiers:[UAAssociatedIdentifiers identifiersWithDictionary:identifiers]];

    [self waitForExpectationsWithTimeout:1 handler:nil];
    XCTAssertEqualObjects(identifiers, [self.analytics currentAssociatedDeviceIdentifiers].allIDs, @"DeviceIdentifiers should match");

    // Verify the event was added
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

/**
 * Test that tracking event adds itself on background
 */
- (void)testTrackingEventBackground{
    [self.analytics trackScreen:@"test_screen"];

    // Expect that the event is added to the mock DB Manager upon background
    XCTestExpectation *eventAdded = [self expectationWithDescription:@"Notification event added"];
    [[[self.mockEventManager expect] andDo:^(NSInvocation *invocation) {
        [eventAdded fulfill];
    }] addEvent:[OCMArg checkWithBlock:^BOOL(id obj) {
        if (![obj isKindOfClass:[UAScreenTrackingEvent class]]) {
            return NO;
        }

        UAScreenTrackingEvent *event = obj;

        return [event.screen isEqualToString:@"test_screen"];
    }] sessionID:OCMOCK_ANY];

    // Background
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidEnterBackgroundNotification
                                                        object:nil];

    [self waitForExpectationsWithTimeout:1 handler:nil];

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
    }] addEvent:[OCMArg checkWithBlock:^BOOL(id obj) {
        if (![obj isKindOfClass:[UAScreenTrackingEvent class]]) {
            return NO;
        }

        UAScreenTrackingEvent *event = obj;

        return [event.screen isEqualToString:@"test_screen"];
    }] sessionID:OCMOCK_ANY];

    // Terminate
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillTerminateNotification
                                                        object:nil];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    [self.mockEventManager verify];
}

// Tests that starting a screen tracking event when one is already started adds the event with the correct start and stop times
- (void)testStartTrackScreenAddEvent {

    [self.analytics trackScreen:@"first_screen"];
    __block NSTimeInterval approxStartTime = [NSDate date].timeIntervalSince1970;

    // Expect that the mock event is added to the mock DB Manager
    XCTestExpectation *eventAdded = [self expectationWithDescription:@"Notification event added"];
    [[[self.mockEventManager expect] andDo:^(NSInvocation *invocation) {
        [eventAdded fulfill];
    }] addEvent:[OCMArg checkWithBlock:^BOOL(id obj) {
        if (![obj isKindOfClass:[UAScreenTrackingEvent class]]) {
            return NO;
        }

        UAScreenTrackingEvent *event = obj;

        XCTAssertEqualWithAccuracy(event.startTime, approxStartTime, 1);
        XCTAssertEqualWithAccuracy(event.stopTime, [NSDate date].timeIntervalSince1970, 1);

        return [event.screen isEqualToString:@"first_screen"];
    }] sessionID:OCMOCK_ANY];

    [self.analytics trackScreen:@"second_screen"];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    [self.mockEventManager verify];
}

// Tests forwarding screens to the analytics delegate.
- (void)testForwardScreenTracks {
    id expectedUserInfo = @{ @"screen": @"screen"};

    XCTestExpectation *notificationFired = [self expectationWithDescription:@"Notification event fired"];

    [self startNSNotificationCenterObservingWithBlock:^(NSNotification *notification) {
        XCTAssertEqualObjects(expectedUserInfo, notification.userInfo);
        [notificationFired fulfill];
    } notificationName:UAScreenTracked sender:self.analytics];

    [self.analytics trackScreen:@"screen"];

    [self waitForExpectationsWithTimeout:10 handler:nil];
}

// Tests forwarding region events to the analytics delegate.
- (void)testForwardRegionEvents {
    XCTestExpectation *notificationFired = [self expectationWithDescription:@"Notification event fired"];

    [self startNSNotificationCenterObservingWithBlock:^(NSNotification *notification) {
        [notificationFired fulfill];
    } notificationName:UARegionEventAdded sender:self.analytics];

    UARegionEvent *regionEnter = [UARegionEvent regionEventWithRegionID:@"region" source:@"test" boundaryEvent:UABoundaryEventEnter];
    [self.analytics addEvent:regionEnter];

    [self waitForExpectationsWithTimeout:10 handler:nil];
}

// Tests forwarding custom events to the analytics delegate.
- (void)testForwardCustomEvents {
    XCTestExpectation *notificationFired = [self expectationWithDescription:@"Notification event fired"];

    [self startNSNotificationCenterObservingWithBlock:^(NSNotification *notification) {
        [notificationFired fulfill];
    } notificationName:UACustomEventAdded sender:self.analytics];

    UACustomEvent *purchase = [UACustomEvent eventWithName:@"purchase" value:@(100)];
    [self.analytics addEvent:purchase];

    [self waitForExpectationsWithTimeout:10 handler:nil];
}

// Test disabling / enabling the analytics component disables / enables eventmanager uploads
- (void)testComponentEnabledSwitch {
    // expectations
    [[self.mockEventManager expect] setUploadsEnabled:NO];
    [[self.mockEventManager expect] cancelUpload];
    
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


@end
