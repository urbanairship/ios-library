/* Copyright Airship and Contributors */

#import "UABaseTest.h"

#import "UAEventAPIClient+Internal.h"
#import "UARuntimeConfig.h"
#import "UAirship+Internal.h"
#import "UAPush+Internal.h"
#import "UAKeychainUtils+Internal.h"

@interface UAEventAPIClientTest : UABaseTest
@property (nonatomic, strong) id mockPush;
@property (nonatomic, strong) id mockChannel;
@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) id mockTimeZoneClass;
@property (nonatomic, strong) id mockLocaleClass;
@property (nonatomic, strong) id mockSession;
@property (nonatomic, strong) id mockAnalytics;
@property (nonatomic, strong) UAEventAPIClient *client;
@end

@implementation UAEventAPIClientTest

- (void)setUp {
    [super setUp];

    self.mockLocaleClass = [self strictMockForClass:[NSLocale class]];
    self.mockTimeZoneClass = [self strictMockForClass:[NSTimeZone class]];

    self.mockChannel = [self mockForClass:[UAChannel class]];
    self.mockPush = [self mockForClass:[UAPush class]];

    self.mockAirship = [self mockForClass:[UAirship class]];
    [UAirship setSharedAirship:self.mockAirship];
    [[[self.mockAirship stub] andReturn:self.mockPush] push];
    [[[self.mockAirship stub] andReturn:self.mockChannel] channel];

    self.mockAnalytics = [self mockForClass:[UAAnalytics class]];
    [[[self.mockAirship stub] andReturn:self.mockAnalytics] analytics];

    self.mockSession = [self mockForClass:[UARequestSession class]];
    self.client = [UAEventAPIClient clientWithConfig:self.config session:self.mockSession];
}

/**
 * Test the event request
 */
- (void)testEventRequest {
    // Device token
    NSString *deviceTokenString = @"123456789012345678901234567890";
    [[[self.mockPush stub] andReturn:deviceTokenString] deviceToken];
    [[[self.mockPush stub] andReturnValue:@YES] pushTokenRegistrationEnabled];

    // Channel ID
    NSString *channelIDString = @"someChannelID";
    [[[self.mockChannel stub] andReturn:channelIDString] identifier];

    // Opted in for both notifications and background push
    [[[self.mockPush stub] andReturnValue:OCMOCK_VALUE(YES)] userPushNotificationsAllowed];
    [[[self.mockPush stub] andReturnValue:OCMOCK_VALUE(YES)] backgroundPushNotificationsAllowed];

    // Timezone
    NSTimeZone *timeZone = [[NSTimeZone alloc] initWithName:@"America/New_York"];
    [[[self.mockTimeZoneClass stub] andReturn:timeZone] defaultTimeZone];

    // Locale
    NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    [[[self.mockLocaleClass stub] andReturn:locale] currentLocale];

    // SDK Extensions
    [[[self.mockAnalytics stub] andReturn:@{@(UASDKExtensionCordova) : @"1.2.3"}] sdkExtensions];
    [[[self.mockAnalytics stub] andReturn:@"cordova"] nameForSDKExtension:UASDKExtensionCordova];


    BOOL (^checkRequestBlock)(id obj) = ^(id obj) {
        UARequest *request = obj;

        // check the url
        if (![[request.URL absoluteString] isEqualToString:@"https://combine.urbanairship.com/warp9/"]) {
            return NO;
        }

        // check that its a POST
        if (![request.method isEqualToString:@"POST"]) {
            return NO;
        }

        // check the body is set
        if (!request.body.length) {
            return NO;
        }

        // headers
        if ([request.headers[@"X-UA-Push-Address"] isEqualToString:deviceTokenString] &&
            [request.headers[@"X-UA-Channel-ID"] isEqualToString:channelIDString] &&
            [request.headers[@"X-UA-Timezone"] isEqualToString:@"America/New_York"] &&
            [request.headers[@"X-UA-Locale-Language"] isEqualToString:@"en"] &&
            [request.headers[@"X-UA-Locale-Country"] isEqualToString:@"US"] &&
            [request.headers[@"X-UA-Locale-Variant"] isEqualToString:@"POSIX"] &&
            request.headers[@"X-UA-Channel-Opted-In"] &&
            request.headers[@"X-UA-Channel-Background-Enabled"] &&
            [request.headers[@"X-UA-Frameworks"] isEqualToString:@"cordova:1.2.3"]) {

            return YES;
        }

        return NO;
    };

    [(UARequestSession *)[self.mockSession expect] dataTaskWithRequest:[OCMArg checkWithBlock:checkRequestBlock]
                                                     completionHandler:OCMOCK_ANY];

    [self.client uploadEvents:@[@{@"some": @"event"}] completionHandler:^(NSHTTPURLResponse *response) {}];
    
    [self.mockSession verify];
}

/**
 * Test the event request when pushTokenRegistrationEnabled is disabled
 */
- (void)testEventRequestPushTokenRegistarionDisabled {
    // Device token
    NSString *deviceTokenString = @"123456789012345678901234567890";
    [[[self.mockPush stub] andReturn:deviceTokenString] deviceToken];
    [[[self.mockPush stub] andReturnValue:@NO] pushTokenRegistrationEnabled];

    BOOL (^checkRequestBlock)(id obj) = ^(id obj) {
        UARequest *request = obj;

        if ([request.headers[@"X-UA-Push-Address"] isEqualToString:deviceTokenString]) {
            return NO;
        }

        return YES;
    };

    [(UARequestSession *)[self.mockSession expect] dataTaskWithRequest:[OCMArg checkWithBlock:checkRequestBlock]
                                                     completionHandler:OCMOCK_ANY];

    [self.client uploadEvents:@[@{@"some": @"event"}] completionHandler:^(NSHTTPURLResponse * response) {}];
    
    [self.mockSession verify];
}

/**
 * Test the event response is passed back.
 */
- (void)testEventResponse {

    NSHTTPURLResponse *expectedResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:nil];

    [(UARequestSession *)[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler)arg;
        completionHandler(nil, expectedResponse, nil);
    }] dataTaskWithRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Callback called"];
    [self.client uploadEvents:@[@{@"some": @"event"}] completionHandler:^(NSHTTPURLResponse *response) {
        XCTAssertEqualObjects(response, expectedResponse);
        [expectation fulfill];
    }];

    [self waitForTestExpectations];
}





@end
