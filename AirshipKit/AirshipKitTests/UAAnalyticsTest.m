/*
 Copyright 2009-2016 Urban Airship Inc. All rights reserved.
 
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

#import "UAConfig.h"
#import "UAAnalytics+Internal.h"
#import "UAHTTPConnection+Internal.h"
#import "UAAnalyticsTest.h"
#import <OCMock/OCMock.h>
#import <OCMock/OCMConstraint.h>
#import "UAKeychainUtils+Internal.h"
#import "UAPush+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAirship.h"
#import "UAAnalyticsDBManager+Internal.h"
#import "UAEvent+Internal.h"
#import "UAAssociateIdentifiersEvent+Internal.h"
#import "UAScreenTrackingEvent+Internal.h"
#import "UARegionEvent.h"
#import "UACustomEvent.h"

@interface UAAnalyticsTest()
@property (nonatomic, strong) UAAnalytics *analytics;

@property (nonatomic, strong) id mockedKeychainClass;
@property (nonatomic, strong) id mockLocaleClass;
@property (nonatomic, strong) id mockTimeZoneClass;
@property (nonatomic, strong) id mockPush;
@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) id mockDBManager;
@property (nonatomic, strong) id mockApplication;

@property (nonatomic, strong) UAPreferenceDataStore *dataStore;

@property (nonatomic, strong) NSValue *noValue;
@property (nonatomic, strong) NSValue *yesValue;
@end

@implementation UAAnalyticsTest

- (void)setUp {
    [super setUp];

    self.mockedKeychainClass = [OCMockObject mockForClass:[UAKeychainUtils class]];
    [[[self.mockedKeychainClass stub] andReturn:@"some-device-ID"] getDeviceID];

    self.mockLocaleClass = [OCMockObject mockForClass:[NSLocale class]];
    self.mockTimeZoneClass = [OCMockObject mockForClass:[NSTimeZone class]];

    self.mockPush = [OCMockObject niceMockForClass:[UAPush class]];

    self.mockAirship = [OCMockObject niceMockForClass:[UAirship class]];
    [[[self.mockAirship stub] andReturn:self.mockAirship] shared];
    [[[self.mockAirship stub] andReturn:self.mockPush] push];

    self.dataStore = [UAPreferenceDataStore preferenceDataStoreWithKeyPrefix:@"test.analytics"];

    self.mockDBManager = [OCMockObject niceMockForClass:[UAAnalyticsDBManager class]];

    UAConfig *config = [[UAConfig alloc] init];
    self.analytics = [UAAnalytics analyticsWithConfig:config dataStore:self.dataStore];
    self.analytics.analyticsDBManager = self.mockDBManager;

    self.mockApplication = [OCMockObject niceMockForClass:[UIApplication class]];
    [[[self.mockApplication stub] andReturn:self.mockApplication] sharedApplication];

 }

- (void)tearDown {
    [self.mockAirship stopMocking];
    [self.mockedKeychainClass stopMocking];
    [self.mockLocaleClass stopMocking];
    [self.mockTimeZoneClass stopMocking];
    [self.mockPush stopMocking];
    [self.mockDBManager stopMocking];
    [self.mockApplication stopMocking];
    [self.dataStore removeAll];

    [super tearDown];
}

- (void)testRequestTimezoneHeader {
    [self setTimeZone:@"America/New_York"];
    
    NSDictionary *headers = [self.analytics analyticsRequest].headers;
    
    XCTAssertEqualObjects([headers objectForKey:@"X-UA-Timezone"], @"America/New_York", @"Wrong timezone in event headers");
}

- (void)testRequestLocaleHeadersFullCode {
    [self setCurrentLocale:@"en_US_POSIX"];

    NSDictionary *headers = [self.analytics analyticsRequest].headers;
    
    XCTAssertEqualObjects([headers objectForKey:@"X-UA-Locale-Language"], @"en", @"Wrong local language code in event headers");
    XCTAssertEqualObjects([headers objectForKey:@"X-UA-Locale-Country"],  @"US", @"Wrong local country code in event headers");
    XCTAssertEqualObjects([headers objectForKey:@"X-UA-Locale-Variant"],  @"POSIX", @"Wrong local variant in event headers");
}

- (void)testAnalyticRequestLocationHeadersPartialCode {
    [self setCurrentLocale:@"de"];
    
    NSDictionary *headers = [self.analytics analyticsRequest].headers;
    
    XCTAssertEqualObjects([headers objectForKey:@"X-UA-Locale-Language"], @"de", @"Wrong local language code in event headers");
    XCTAssertNil([headers objectForKey:@"X-UA-Locale-Country"], @"Wrong local country code in event headers");
    XCTAssertNil([headers objectForKey:@"X-UA-Locale-Variant"], @"Wrong local variant in event headers");
}

- (void)testRequestEmptyPushAddressHeader {
    [[[self.mockPush stub] andReturn:nil] deviceToken];

    NSDictionary *headers = [self.analytics analyticsRequest].headers;
    XCTAssertNil([headers objectForKey:@"X-UA-Push-Address"], @"Device token should be null in event headers");
}

- (void)testRequestPushAddressHeader {
    NSString *deviceTokenString = @"123456789012345678901234567890";
    [[[self.mockPush stub] andReturn:deviceTokenString] deviceToken];
    [[[self.mockPush stub] andReturnValue:@YES] pushTokenRegistrationEnabled];

    NSDictionary *headers = [self.analytics analyticsRequest].headers;
    XCTAssertEqualObjects([headers objectForKey:@"X-UA-Push-Address"], deviceTokenString, @"Wrong device token in event headers");
}

- (void)testRequestPushAddressHeaderPushTokenRegistrationEnabledNo {
    NSString *deviceTokenString = @"123456789012345678901234567890";
    [[[self.mockPush stub] andReturn:deviceTokenString] deviceToken];
    [[[self.mockPush stub] andReturnValue:@NO] pushTokenRegistrationEnabled];

    NSDictionary *headers = [self.analytics analyticsRequest].headers;
    XCTAssertNil([headers objectForKey:@"X-UA-Push-Address"], @"Device token should be nil when pushTokenRegistrationEnabled is NO.");
}

- (void)testRequestChannelIDHeader {
    NSString *channelIDString = @"someChannelID";
    [[[self.mockPush stub] andReturn:channelIDString] channelID];

    NSDictionary *headers = [self.analytics analyticsRequest].headers;
    XCTAssertEqualObjects([headers objectForKey:@"X-UA-Channel-ID"], channelIDString, @"Wrong channel ID in event headers");
}

- (void)testRequestChannelOptInNoHeader {
    [[[self.mockPush stub] andReturnValue:OCMOCK_VALUE(NO)] userPushNotificationsAllowed];

    NSDictionary *headers = [self.analytics analyticsRequest].headers;
    XCTAssertEqualObjects([headers objectForKey:@"X-UA-Channel-Opted-In"], @"false");
}

- (void)testRequestChannelOptInYesHeader {
    [[[self.mockPush stub] andReturnValue:OCMOCK_VALUE(YES)] userPushNotificationsAllowed];

    NSDictionary *headers = [self.analytics analyticsRequest].headers;
    XCTAssertEqualObjects([headers objectForKey:@"X-UA-Channel-Opted-In"], @"true");
}

- (void)testRequestChannelBackgroundEnabledNoHeader {
    [[[self.mockPush stub] andReturnValue:OCMOCK_VALUE(NO)] backgroundPushNotificationsAllowed];

    NSDictionary *headers = [self.analytics analyticsRequest].headers;
    XCTAssertEqualObjects([headers objectForKey:@"X-UA-Channel-Background-Enabled"], @"false");
}

- (void)testRequestChannelBackgroundEnabledYesHeader {
    [[[self.mockPush stub] andReturnValue:OCMOCK_VALUE(YES)] backgroundPushNotificationsAllowed];

    NSDictionary *headers = [self.analytics analyticsRequest].headers;
    XCTAssertEqualObjects([headers objectForKey:@"X-UA-Channel-Background-Enabled"], @"true");
}

- (void)restoreSavedUploadEventSettingsEmptyDataStore {
    [self.analytics restoreSavedUploadEventSettings];

    // Should try to set the values to 0 and the setter should normalize them to the min values.
    XCTAssertEqual(self.analytics.maxTotalDBSize, kMinTotalDBSizeBytes, @"maxTotalDBSize is setting an incorrect value when trying to set the value to 0");
    XCTAssertEqual(self.analytics.maxBatchSize, kMinBatchSizeBytes, @"maxBatchSize is setting an incorrect value when trying to set the value to 0");
    XCTAssertEqual(self.analytics.maxWait, kMinWaitSeconds, @"maxWait is setting an incorrect value when trying to set the value to 0");
    XCTAssertEqual(self.analytics.minBatchInterval, kMinBatchIntervalSeconds, @"minBatchInterval is setting an incorrect value when trying to set the value to 0");
}

- (void)restoreSavedUploadEventSettingsExistingData {
    // Set valid data
    [self.dataStore setValue:@(kMinTotalDBSizeBytes + 5) forKey:kMaxTotalDBSizeUserDefaultsKey];
    [self.dataStore setValue:@(kMinBatchSizeBytes + 5) forKey:kMaxBatchSizeUserDefaultsKey];
    [self.dataStore setValue:@(kMinWaitSeconds + 5) forKey:kMaxWaitUserDefaultsKey];
    [self.dataStore setValue:@(kMinBatchIntervalSeconds + 5) forKey:kMinBatchIntervalUserDefaultsKey];

    [self.analytics restoreSavedUploadEventSettings];

    // Should try to set the values to 0 and the setter should normalize them to the min values.
    XCTAssertEqual(self.analytics.maxTotalDBSize, kMinTotalDBSizeBytes + 5, @"maxTotalDBSize value did not restore properly");
    XCTAssertEqual(self.analytics.maxBatchSize, kMinBatchSizeBytes + 5, @"maxBatchSize value did not restore properly");
    XCTAssertEqual(self.analytics.maxWait, kMinWaitSeconds + 5, @"maxWait value did not restore properly");
    XCTAssertEqual(self.analytics.minBatchInterval, kMinBatchIntervalSeconds + 5, @"minBatchInterval value did not restore properly");
}

- (void)testSaveUploadEventSettings {
    [self.analytics saveUploadEventSettings];

    XCTAssertEqual(self.analytics.maxTotalDBSize, [[self.dataStore valueForKey:kMaxTotalDBSizeUserDefaultsKey] integerValue]);
    XCTAssertEqual(self.analytics.maxBatchSize, [[self.dataStore valueForKey:kMaxBatchSizeUserDefaultsKey] integerValue]);
    XCTAssertEqual(self.analytics.maxWait,[[self.dataStore valueForKey:kMaxWaitUserDefaultsKey] integerValue]);
    XCTAssertEqual(self.analytics.minBatchInterval,[[self.dataStore valueForKey:kMinBatchIntervalUserDefaultsKey] integerValue]);
}

- (void)testUpdateAnalyticsParameters {
    // Create headers with response values for the event header settings
    NSMutableDictionary *headers = [NSMutableDictionary dictionaryWithCapacity:4];
    [headers setValue:[NSNumber numberWithInt:11] forKey:@"X-UA-Max-Total"];
    [headers setValue:[NSNumber numberWithInt:11] forKey:@"X-UA-Max-Batch"];
    [headers setValue:[NSNumber numberWithInt:8*24*3600] forKey:@"X-UA-Max-Wait"];
    [headers setValue:[NSNumber numberWithInt:62] forKey:@"X-UA-Min-Batch-Interval"];

    id mockResponse = [OCMockObject niceMockForClass:[NSHTTPURLResponse class]];
    [[[mockResponse stub] andReturn:headers] allHeaderFields];

    [self.analytics updateAnalyticsParametersWithHeaderValues:mockResponse];

    // Make sure all the expected settings are set to the current analytics properties
    XCTAssertEqual(11 * 1024, [[self.dataStore valueForKey:kMaxTotalDBSizeUserDefaultsKey] integerValue]);
    XCTAssertEqual(11 * 1024, [[self.dataStore valueForKey:kMaxBatchSizeUserDefaultsKey] integerValue]);
    XCTAssertEqual(8*24*3600, [[self.dataStore valueForKey:kMaxWaitUserDefaultsKey] integerValue]);
    XCTAssertEqual(62,[[self.dataStore valueForKey:kMinBatchIntervalUserDefaultsKey] integerValue]);

    [mockResponse stopMocking];
}

- (void)testSetMaxTotalDBSize {
    // Set a value higher then the max, should set to the max
    self.analytics.maxTotalDBSize = kMaxTotalDBSizeBytes + 1;
    XCTAssertEqual(self.analytics.maxTotalDBSize, kMaxTotalDBSizeBytes, @"maxTotalDBSize is able to be set above the max value");

    // Set a value lower then then min, should set to the min
    self.analytics.maxTotalDBSize = kMinTotalDBSizeBytes - 1;
    XCTAssertEqual(self.analytics.maxTotalDBSize, kMinTotalDBSizeBytes, @"maxTotalDBSize is able to be set below the min value");

    // Set a value between
    self.analytics.maxTotalDBSize = kMinTotalDBSizeBytes + 1;
    XCTAssertEqual(self.analytics.maxTotalDBSize, kMinTotalDBSizeBytes + 1, @"maxTotalDBSize is unable to be set to a valid value");
}

- (void)testSetMaxBatchSize {
    // Set a value higher then the max, should set to the max
    self.analytics.maxBatchSize = kMaxBatchSizeBytes + 1;
    XCTAssertEqual(self.analytics.maxBatchSize, kMaxBatchSizeBytes, @"maxBatchSize is able to be set above the max value");

    // Set a value lower then then min, should set to the min
    self.analytics.maxBatchSize = kMinBatchSizeBytes - 1;
    XCTAssertEqual(self.analytics.maxBatchSize, kMinBatchSizeBytes, @"maxBatchSize is able to be set below the min value");

    // Set a value between
    self.analytics.maxBatchSize = kMinBatchSizeBytes + 1;
    XCTAssertEqual(self.analytics.maxBatchSize, kMinBatchSizeBytes + 1, @"maxBatchSize is unable to be set to a valid value");
}

- (void)testSetMaxWait {
    // Set a value higher then the max, should set to the max
    self.analytics.maxWait = kMaxWaitSeconds + 1;
    XCTAssertEqual(self.analytics.maxWait, kMaxWaitSeconds, @"maxWait is able to be set above the max value");

    // Set a value lower then then min, should set to the min
    self.analytics.maxWait = kMinWaitSeconds - 1;
    XCTAssertEqual(self.analytics.maxWait, kMinWaitSeconds, @"maxWait is able to be set below the min value");

    // Set a value between
    self.analytics.maxWait = kMinWaitSeconds + 1;
    XCTAssertEqual(self.analytics.maxWait, kMinWaitSeconds + 1, @"maxWait is unable to be set to a valid value");
}

- (void)testSetMinBatchInterval {
    // Set a value higher then the max, should set to the max
    self.analytics.minBatchInterval = kMaxBatchIntervalSeconds + 1;
    XCTAssertEqual(self.analytics.minBatchInterval, kMaxBatchIntervalSeconds, @"minBatchInterval is able to be set above the max value");

    // Set a value lower then then min, should set to the min
    self.analytics.minBatchInterval = kMinBatchIntervalSeconds - 1;
    XCTAssertEqual(self.analytics.minBatchInterval, kMinBatchIntervalSeconds, @"minBatchInterval is able to be set below the min value");

    // Set a value between
    self.analytics.minBatchInterval = kMinBatchIntervalSeconds + 1;
    XCTAssertEqual(self.analytics.minBatchInterval, kMinBatchIntervalSeconds + 1, @"minBatchInterval is unable to be set to a valid value");
}

- (void)testIsEventValid {
    // Create a valid dictionary
    NSMutableDictionary *event = [self createValidEvent];
    XCTAssertTrue([self.analytics isEventValid:event], @"isEventValid should be true for a valid event");
}

- (void)testIsEventValidEmptyDictionary {
    NSMutableDictionary *invalidEventData = [NSMutableDictionary dictionary];
    XCTAssertFalse([self.analytics isEventValid:invalidEventData], @"isEventValid should be false for an empty dictionary");
}

- (void)testIsEventValidInvalidValues {
    NSArray *eventKeysToTest = @[@"event_id", @"session_id", @"type", @"time", @"event_size", @"data"];

    for (NSString *key in eventKeysToTest) {
        // Create a valid event
        NSMutableDictionary *event = [self createValidEvent];

        // Make the value invalid - empty array is an invalid type for all the fields
        [event setValue:@[] forKey:key];
        XCTAssertFalse([self.analytics isEventValid:event], @"isEventValid did not detect invalid %@", key);


        // Remove the value
        [event setValue:NULL forKey:key];
        XCTAssertFalse([self.analytics isEventValid:event], @"isEventValid did not detect empty %@", key);
    }
}

/**
 * Test disabling analytics will result in deleting the database.
 */
- (void)testDisablingAnalytics {
    [[self.mockDBManager expect] resetDB];
    self.analytics.enabled = NO;

    [self.mockDBManager verify];
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
    self.analytics = [UAAnalytics analyticsWithConfig:[UAConfig config] dataStore:self.dataStore];

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
    self.analytics = [UAAnalytics analyticsWithConfig:config dataStore:self.dataStore];

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
    id mockEvent = [OCMockObject niceMockForClass:[UAEvent class]];
    [[[mockEvent stub] andReturnValue:OCMOCK_VALUE(NO)] isValid];

    // Add invalid event
    [self.analytics addEvent:mockEvent];

    // Ensure event add is never attempted
    [[self.mockDBManager reject] addEvent:mockEvent withSessionID:OCMOCK_ANY];

    [self.mockDBManager  verify];
    [mockEvent stopMocking];
}

/**
 * Tests adding a valid event.
 * Expects adding a valid event succeeds and increases database size.
 */
- (void)testAddEvent {
    // Mock valid event
    id mockEvent = [OCMockObject niceMockForClass:[UAEvent class]];
    [[[mockEvent stub] andReturnValue:OCMOCK_VALUE(YES)] isValid];

    // Ensure addEvent:withSessionID is called
    [[self.mockDBManager expect] addEvent:OCMOCK_ANY withSessionID:OCMOCK_ANY];

    // Add valid event
    [self.analytics addEvent:mockEvent];

    [self.mockDBManager verify];
    [mockEvent stopMocking];
}

/**
 * Tests adding a valid event when analytics is disabled.
 * Expects adding a valid event when analytics is disabled drops event.
 */
- (void)testAddEventAnalyticsDisabled {
    self.analytics.enabled = false;

    // Mock valid event
    id mockEvent = [OCMockObject niceMockForClass:[UAEvent class]];
    [[[mockEvent stub] andReturnValue:OCMOCK_VALUE(YES)] isValid];

    // Add valid event
    [self.analytics addEvent:mockEvent];

    // Ensure event add is never attempted
    [[self.mockDBManager reject] addEvent:OCMOCK_ANY withSessionID:OCMOCK_ANY];

    [self.mockDBManager verify];
    [mockEvent stopMocking];
}

/**
 * Tests a timer is created with a background task with a specified delay.
 * Expects that a timer is added with specified delay when sendWithDelay: is called.
 */
- (void)testSendWithDelay {

    // Mock channel ID to pass channel ID check
    [[[self.mockPush stub] andReturn:OCMOCK_ANY] channelID];

    // Partial mock analytics just so we can pass hasEventsToSend checkout without adding an event
    id mockAnalytics = [OCMockObject partialMockForObject:self.analytics];
    [[[mockAnalytics stub] andReturnValue:OCMOCK_VALUE(YES)] hasEventsToSend];

    // Mock background task so background task check passes
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)1)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    // Send with delay of 10 seconds
    [self.analytics sendWithDelay:10];

    // Check that timer is set with a fireDate of 10 ± 2 seconds in the future
    XCTAssertEqualWithAccuracy([[self.analytics.sendTimer fireDate] timeIntervalSince1970], [[NSDate date] timeIntervalSince1970] + 10, 2);

    [mockAnalytics stopMocking];
}

/**
 * Tests timeToWaitBeforeSendingNextBatch when initialDelayRemaining is 0.
 * Expects that timeToWaitBeforeSendingNextBatch is self.minBatchInterval - timeSinceLastSend when initialDelayRemaining is 0.
 */
- (void)testTimeToWaitBeforeSendingNextBatchNoInitialDelayRemaining {

    // Partial mock analytics
    id mockAnalytics = [OCMockObject partialMockForObject:self.analytics];
    id mockDate = [OCMockObject niceMockForClass:[NSDate class]];

    // Mock current date as epoch date 1970-01-01 00:00:00 +0000
    [[[mockDate stub] andReturn:[NSDate dateWithTimeIntervalSince1970:0]] date];

    // Mock timeIntervalSinceNow so that initialDelayRemaining = [self.analytics.earliestInitialSendTime timeIntervalSinceNow] = 0
    self.analytics.earliestInitialSendTime = mockDate;
    NSTimeInterval initialDelayRemaining = 0;
    [[[mockDate stub] andReturnValue:OCMOCK_VALUE(initialDelayRemaining)] timeIntervalSinceNow];

    // Set lastSendTime as epoch date 1970-01-01 00:00:00 +0000
    self.analytics.lastSendTime = [NSDate dateWithTimeIntervalSince1970:0];

    // Set minBatchInterval as 60s
    self.analytics.minBatchInterval = 60;

    NSTimeInterval timeSinceLastSend = [[NSDate date] timeIntervalSinceDate:self.analytics.lastSendTime];

    // Assert that the unmocked analytics timeToWaitBeforeSendingNextBatch returns (self.analytics.minBatchInterval - timeSinceLastSend)
    XCTAssertTrue(self.analytics.timeToWaitBeforeSendingNextBatch == (self.analytics.minBatchInterval - timeSinceLastSend));

    [mockAnalytics stopMocking];
    [mockDate stopMocking];
}

/**
 * Tests timeToWaitBeforeSendingNextBatch timeSinceLastSend > minBatchInterval and delay is 0.
 * Expects that initialDelayRemaining is returned.
 */
- (void)testTimeToWaitBeforeSendingNextBatchNoDelay{

    // Partial mock analytics
    id mockAnalytics = [OCMockObject partialMockForObject:self.analytics];
    id mockDate = [OCMockObject niceMockForClass:[NSDate class]];

    // Mock timeIntervalSinceNow so that initialDelayRemaining = 1
    self.analytics.earliestInitialSendTime = mockDate;
    NSTimeInterval initialDelayRemaining = 1;
    [[[mockDate stub] andReturnValue:OCMOCK_VALUE(initialDelayRemaining)] timeIntervalSinceNow];

    // Set lastSendTime as epoch date 1970-01-01 00:00:00 +0000
    self.analytics.lastSendTime = [NSDate dateWithTimeIntervalSince1970:0];

    // Set minBatchInterval as 0s
    self.analytics.minBatchInterval = 0;

    // Assert that the unmocked analytics timeToWaitBeforeSendingNextBatch returns (self.analytics.minBatchInterval - timeSinceLastSend)
    XCTAssertTrue(self.analytics.timeToWaitBeforeSendingNextBatch == initialDelayRemaining);

    [mockAnalytics stopMocking];
    [mockDate stopMocking];
}


/**
 * Tests when sendWithDelay: fails to create a background task does not add a timer.
 * Expects that a timer is not added when sendWithDelay fails to create a valid background task.
 */
- (void)testSendWithDelayFailedToCreateBGTask {
    // Partial mock analytics just so we can pass hasEventsToSend checkout without adding an event
    id mockAnalytics = [OCMockObject partialMockForObject:self.analytics];
    [[[mockAnalytics stub] andReturnValue:OCMOCK_VALUE(YES)] hasEventsToSend];

    // Mock background task so background task check fails
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE(UIBackgroundTaskInvalid)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    //Test that timer is nil
    XCTAssertNil(self.analytics.sendTimer);

    // Send with delay of 1 without mocking a background task
    [self.analytics sendWithDelay:1];

    //Test that timer is still nil due background task check failing
    XCTAssertNil(self.analytics.sendTimer);

    [mockAnalytics stopMocking];
}

/**
 * Tests sendWithDelay: with a delay that is shorter then the existing timer's fireDate.
 * Expects that a new timer is not added when timer delay date from now is sooner than the timer's fire date.
 */
- (void)testSendWithDelayExistingShorterTimerDelay {

    // Mock channel ID to pass channel ID check
    [[[self.mockPush stub] andReturn:OCMOCK_ANY] channelID];

    // Partial mock analytics just so we can pass hasEventsToSend checkout without adding an event
    id mockAnalytics = [OCMockObject partialMockForObject:self.analytics];

    [[[mockAnalytics stub] andReturnValue:OCMOCK_VALUE(YES)] hasEventsToSend];

    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)1)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    // Send with delay of 30 seconds
    [self.analytics sendWithDelay:30];

    // Check that timer is set with a fireDate of 30 ± 2 seconds in the future
    XCTAssertEqualWithAccuracy([[self.analytics.sendTimer fireDate] timeIntervalSince1970], [[NSDate date] timeIntervalSince1970] + 30, 2);

    // Send with delay of 10 second
    [self.analytics sendWithDelay:10];

    // Check that timer is now set with a fireDate of 10 ± 2 seconds in the future
    XCTAssertEqualWithAccuracy([[self.analytics.sendTimer fireDate] timeIntervalSince1970], [[NSDate date] timeIntervalSince1970] + 10, 2);

    [mockAnalytics stopMocking];
}

/**
 * Test associateIdentifiers: adds an UAAssociateIdentifiersEvent with the
 * expected identifiers.
 */
- (void)testAssociateDeviceIdentifiers {

    NSDictionary *identifiers = @{@"some identifer": @"some value"};

    [[self.mockDBManager expect] addEvent:[OCMArg checkWithBlock:^BOOL(id obj) {
        if (![obj isKindOfClass:[UAAssociateIdentifiersEvent class]]) {
            return NO;
        }

        UAAssociateIdentifiersEvent *event = obj;
        return [event.data isEqualToDictionary:identifiers];
    }] withSessionID:OCMOCK_ANY];

    // Associate the identifiers
    [self.analytics associateDeviceIdentifiers:[UAAssociatedIdentifiers identifiersWithDictionary:identifiers]];

    XCTAssertEqualObjects(identifiers, [self.analytics currentAssociatedDeviceIdentifiers].allIDs, @"DeviceIdentifiers should match");

    // Verify the event was added
    [self.mockDBManager verify];
}

/**
 * Tests sendWithDelay: with a delay that is longer then the existing timer's fireDate.
 * Expects that a new timer is added when timer delay date from now is sooner than the timer's fire date.
 */
- (void)testSendWithDelayExistingLongerTimerDelay {

    // Mock channel ID to pass channel ID check
    [[[self.mockPush stub] andReturn:OCMOCK_ANY] channelID];

    // Partial mock analytics just so we can pass hasEventsToSend checkout without adding an event
    id mockAnalytics = [OCMockObject partialMockForObject:self.analytics];

    [[[mockAnalytics stub] andReturnValue:OCMOCK_VALUE(YES)] hasEventsToSend];

    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)1)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    // Send with delay of 10 seconds
    [self.analytics sendWithDelay:10];

    // Check that timer is set with a fireDate of 10 ± 5 seconds in the future
    XCTAssertEqualWithAccuracy([[self.analytics.sendTimer fireDate] timeIntervalSince1970], [[NSDate date] timeIntervalSince1970] + 10, 2);

    // Send with delay of 30 second
    [self.analytics sendWithDelay:30];

    // Check that timer is still set with a fireDate of 10 ± 2 seconds in the future
    XCTAssertEqualWithAccuracy([[self.analytics.sendTimer fireDate] timeIntervalSince1970], [[NSDate date] timeIntervalSince1970] + 10, 2);

    // Check that timer is not set with a fireDate of 30 ± 2 seconds in the future
    XCTAssertNotEqualWithAccuracy([[self.analytics.sendTimer fireDate] timeIntervalSince1970], [[NSDate date] timeIntervalSince1970] + 30, 2);

    [mockAnalytics stopMocking];
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
    [[self.mockDBManager expect] addEvent:[OCMArg checkWithBlock:^BOOL(id obj) {
        if (![obj isKindOfClass:[UAScreenTrackingEvent class]]) {
            return NO;
        }

        UAScreenTrackingEvent *event = obj;

        return [event.screen isEqualToString:@"test_screen"];
    }] withSessionID:OCMOCK_ANY];

    // Enter background
    [self.analytics enterBackground];

    [self.mockDBManager verify];
}

/**
 * Test tracking event adds itself and is set to nil on terminate event.
 */
- (void)testTrackingEventTerminate {

    [self.analytics trackScreen:@"test_screen"];

    // Expect that the event is added to the mock DB Manager upon terminate
    [[self.mockDBManager expect] addEvent:[OCMArg checkWithBlock:^BOOL(id obj) {
        if (![obj isKindOfClass:[UAScreenTrackingEvent class]]) {
            return NO;
        }

        UAScreenTrackingEvent *event = obj;

        return [event.screen isEqualToString:@"test_screen"];
    }] withSessionID:OCMOCK_ANY];

    // Terminate
    [self.analytics willTerminate];

    [self.mockDBManager verify];
}

// Tests that starting a screen tracking event when one is already started adds the event with the correct start and stop times
- (void)testStartTrackScreenAddEvent {

    [self.analytics trackScreen:@"first_screen"];
    __block NSTimeInterval approxStartTime = [NSDate date].timeIntervalSince1970;

    // Expect that the mock event is added to the mock DB Manager
    [[self.mockDBManager expect] addEvent:[OCMArg checkWithBlock:^BOOL(id obj) {
        if (![obj isKindOfClass:[UAScreenTrackingEvent class]]) {
            return NO;
        }

        UAScreenTrackingEvent *event = obj;

        XCTAssertEqualWithAccuracy(event.startTime, approxStartTime, 1);
        XCTAssertEqualWithAccuracy(event.stopTime, [NSDate date].timeIntervalSince1970, 1);

        return [event.screen isEqualToString:@"first_screen"];
    }] withSessionID:OCMOCK_ANY];

    [self.analytics trackScreen:@"second_screen"];

    [self.mockDBManager verify];
}

// Tests forwarding screens to the analytics delegate.
- (void)testForwardScreenTracks {
    id mockDelegate = [OCMockObject niceMockForProtocol:@protocol(UAAnalyticsDelegate)];
    self.analytics.delegate = mockDelegate;

    [[mockDelegate expect] screenTracked:@"screen"];
    [self.analytics trackScreen:@"screen"];

    [mockDelegate verify];
    [mockDelegate stopMocking];
}

// Tests forwarding region events to the analytics delegate.
- (void)testForwardRegionEvents {
    id mockDelegate = [OCMockObject niceMockForProtocol:@protocol(UAAnalyticsDelegate)];
    self.analytics.delegate = mockDelegate;

    UARegionEvent *regionEnter = [UARegionEvent regionEventWithRegionID:@"region" source:@"test" boundaryEvent:UABoundaryEventEnter];

    [[mockDelegate expect] regionEventAdded:regionEnter];
    [self.analytics addEvent:regionEnter];

    [mockDelegate verify];
    [mockDelegate stopMocking];
}

// Tests forwarding cusotm events to the analytics delegate.
- (void)testForwardCustomEvents {
    id mockDelegate = [OCMockObject niceMockForProtocol:@protocol(UAAnalyticsDelegate)];
    self.analytics.delegate = mockDelegate;

    UACustomEvent *purchase = [UACustomEvent eventWithName:@"purchase" value:@(100)];

    [[mockDelegate expect] customEventAdded:purchase];
    [self.analytics addEvent:purchase];

    [mockDelegate verify];
    [mockDelegate stopMocking];
}



#pragma Helpers

- (void)setCurrentLocale:(NSString *)localeCode {
    NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier:localeCode];

    [[[self.mockLocaleClass stub] andReturn:locale] currentLocale];
}

- (void)setTimeZone:(NSString *)name {
    NSTimeZone *timeZone = [[NSTimeZone alloc] initWithName:name];

    [[[self.mockTimeZoneClass stub] andReturn:timeZone] defaultTimeZone];
}

-(NSMutableDictionary *) createValidEvent {
    return [@{@"event_id": @"some-event-ID",
             @"data": [NSMutableData dataWithCapacity:1],
             @"session_id": @"some-session-ID",
             @"type": @"base",
             @"time":[NSString stringWithFormat:@"%f",[[NSDate date] timeIntervalSince1970]],
             @"event_size":@"40"} mutableCopy];
}

@end
