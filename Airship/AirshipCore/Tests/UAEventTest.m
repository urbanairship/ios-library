/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>

#import "UAEvent.h"
#import "UAirship+Internal.h"
#import "UAAnalytics.h"
#import "AirshipTests-Swift.h"
@import AirshipCore;

@interface UAEventTest : UAAirshipBaseTest

// stubs
@property (nonatomic, strong) id analytics;
@property (nonatomic, strong) id airship;
@property (nonatomic, strong) id reachability;
@property (nonatomic, strong) id timeZone;
@property (nonatomic, strong) id application;
@property (nonatomic, strong) id push;
@property (nonatomic, strong) UATestChannel *testChannel;
@property (nonatomic, strong) id currentDevice;
@property (nonatomic, strong) id utils;
@property (nonatomic, strong) UAPrivacyManager *privacyManager;
@end

@implementation UAEventTest

- (void)setUp {
    [super setUp];

    self.testChannel = [[UATestChannel alloc] init];
    self.privacyManager = [[UAPrivacyManager alloc] initWithDataStore:self.dataStore defaultEnabledFeatures:UAFeaturesNone];
    self.analytics = [self mockForClass:[UAAnalytics class]];
    self.push = [self mockForClass:[UAPush class]];

    self.airship = [self mockForClass:[UAirship class]];

    [[[self.airship stub] andReturn:self.analytics] sharedAnalytics];
    [[[self.airship stub] andReturn:self.push] push];
    [[[self.airship stub] andReturn:self.privacyManager] privacyManager];

    [UAirship setSharedAirship:self.airship];

    self.utils = [self strictMockForClass:[UAUtils class]];

    self.timeZone = [self mockForClass:[NSTimeZone class]];
    [[[self.timeZone stub] andReturn:self.timeZone] defaultTimeZone];

    self.application = [self mockForClass:[UIApplication class]];
    [[[self.application stub] andReturn:self.application] sharedApplication];

    self.currentDevice = [self mockForClass:[UIDevice class]];
    [[[self.currentDevice stub] andReturn:self.currentDevice] currentDevice];
}

- (void)tearDown {   
    [self.timeZone stopMocking];
    [super tearDown];
}

/**
 * Test app init event
 */
- (void)testAppInitEvent {
    [[[self.analytics stub] andReturn:@"push ID"] conversionSendID];
    [[[self.analytics stub] andReturn:@"base64metadataString"] conversionPushMetadata];

    [[[self.timeZone stub] andReturnValue:OCMOCK_VALUE((NSInteger)2000)] secondsFromGMT];

    [[[self.timeZone stub] andReturnValue:OCMOCK_VALUE(YES)] isDaylightSavingTime];

    [(UIDevice *)[[self.currentDevice stub] andReturn:@"os version"]systemVersion];

    [[[self.application stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateActive)] applicationState];

    [[[self.push stub] andReturnValue:OCMOCK_VALUE(UAAuthorizationStatusNotDetermined)] authorizationStatus];

    NSDictionary *expectedData = @{@"connection_type": @"wifi",
                                   @"push_id": @"push ID",
                                   @"metadata": @"base64metadataString",
                                   @"time_zone": @2000,
                                   @"daylight_savings": @"true",
                                   @"notification_types": @[],
                                   @"notification_authorization": @"not_determined",
                                   @"os_version": @"os version",
                                   @"lib_version": UAirshipVersion.get,
                                   @"package_version": @"",
                                   @"foreground": @"true"};

    UAAppInitEvent *event = [[UAAppInitEvent alloc] init];

    XCTAssertEqualObjects(event.data, expectedData, @"Event data is unexpected.");
    XCTAssertEqualObjects(event.eventType, @"app_init", @"Event type is unexpected.");

}

/**
 * Test app foreground event
 */
- (void)testAppForegroundEvent {
    [[[self.analytics stub] andReturn:@"push ID"] conversionSendID];
    [[[self.analytics stub] andReturn:@"base64metadataString"] conversionPushMetadata];

    [[[self.timeZone stub] andReturnValue:OCMOCK_VALUE((NSInteger)2000)] secondsFromGMT];
    [[[self.timeZone stub] andReturnValue:OCMOCK_VALUE(YES)] isDaylightSavingTime];

    [(UIDevice *)[[self.currentDevice stub] andReturn:@"os version"]systemVersion];

    [[[self.push stub] andReturnValue:OCMOCK_VALUE(UAAuthorizationStatusProvisional)] authorizationStatus];

    // Same as app init but without the foreground key
    NSDictionary *expectedData = @{@"connection_type": @"wifi",
                                   @"push_id": @"push ID",
                                   @"metadata": @"base64metadataString",
                                   @"time_zone": @2000,
                                   @"daylight_savings": @"true",
                                   @"notification_types": @[],
                                   @"notification_authorization": @"provisional",
                                   @"os_version": @"os version",
                                   @"lib_version": UAirshipVersion.get,
                                   @"package_version": @""};


    UAAppForegroundEvent *event = [[UAAppForegroundEvent alloc] init];

    XCTAssertEqualObjects(event.data, expectedData, @"Event data is unexpected.");
    XCTAssertEqualObjects(event.eventType, @"app_foreground", @"Event type is unexpected.");

}

/**
 * Test app exit event
 */
- (void)testAppExitEvent {

    [[[self.analytics stub] andReturn:@"push ID"] conversionSendID];
    [[[self.analytics stub] andReturn:@"base64metadataString"] conversionPushMetadata];
    
    NSDictionary *expectedData = @{@"connection_type": @"wifi",
                                   @"push_id": @"push ID",
                                   @"metadata": @"base64metadataString"};

    UAAppExitEvent *event = [[UAAppExitEvent alloc] init];
    XCTAssertEqualObjects(event.data, expectedData, @"Event data is unexpected.");
    XCTAssertEqualObjects(event.eventType, @"app_exit", @"Event type is unexpected.");
}

/**
 * Test app background event
 */
- (void)UAAppBackgroundEvent {
    NSDictionary *expectedData = @{@"class_name": @""};

    UAAppBackgroundEvent *event = [[UAAppBackgroundEvent alloc] init];
    XCTAssertEqualObjects(event.data, expectedData, @"Event data is unexpected.");
    XCTAssertEqualObjects(event.eventType, @"app_background", @"Event type is unexpected.");
}

/**
 * Test device registration event when pushTokenRegistrationEnabled is YES.
 */
- (void)testRegistrationEvent {
    [self.privacyManager enableFeatures:UAFeaturesPush];
    [[[self.push stub] andReturn:@"a12312ad"] deviceToken];
    self.testChannel.identifier = @"someChannelID";

    NSDictionary *expectedData = @{@"device_token": @"a12312ad",
                                   @"channel_id": @"someChannelID",
                                   };

    UADeviceRegistrationEvent *event = [[UADeviceRegistrationEvent alloc] initWithChannel:self.testChannel push:self.push privacyManager:self.privacyManager];
    
    XCTAssertEqualObjects(event.data, expectedData, @"Event data is unexpected.");
    XCTAssertEqualObjects(event.eventType, @"device_registration", @"Event type is unexpected.");
}

/**
 * Test device registration event when pushTokenRegistrationEnabled is NO.
 */
- (void)testRegistrationEventPushTokenRegistrationEnabledNo {
    self.testChannel.identifier = @"someChannelID";
    [self.privacyManager disableFeatures:UAFeaturesPush];
    [[[self.push stub] andReturn:@"a12312ad"] deviceToken];
    

    NSDictionary *expectedData = @{@"channel_id": @"someChannelID"};

    UADeviceRegistrationEvent *event = [[UADeviceRegistrationEvent alloc] initWithChannel:self.testChannel push:self.push privacyManager:self.privacyManager];
    XCTAssertEqualObjects(event.data, expectedData, @"Event data is unexpected.");
    XCTAssertEqualObjects(event.eventType, @"device_registration", @"Event type is unexpected.");
}

/**
 * Test push received event
 */
- (void)testPushReceivedEvent {
    id notification = @{ @"_": @"push ID",
                         @"_uamid": @"rich push ID",
                         @"com.urbanairship.metadata": @"base64metadataString"};


    NSDictionary *expectedData = @{@"push_id": @"push ID",
                                   @"metadata": @"base64metadataString"};

    UAPushReceivedEvent *event = [[UAPushReceivedEvent alloc] initWithNotification:notification];
    XCTAssertEqualObjects(event.data, expectedData, @"Event data is unexpected.");
    XCTAssertEqualObjects(event.eventType, @"push_received", @"Event type is unexpected.");
}

/**
 * Test push received event without a push ID will send "MISSING_SEND_ID".
 */
- (void)testPushReceivedEventNoPushID {
    id notification = @{ @"_uamid": @"rich push ID" };


    NSDictionary *expectedData = @{@"push_id": @"MISSING_SEND_ID"};

    UAPushReceivedEvent *event = [[UAPushReceivedEvent alloc] initWithNotification:notification];
    XCTAssertEqualObjects(event.data, expectedData, @"Event data is unexpected.");
    XCTAssertEqualObjects(event.eventType, @"push_received", @"Event type is unexpected.");
}

@end
