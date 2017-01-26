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

#import "UAEventAPIClient+Internal.h"
#import "UAConfig.h"
#import "UAirship.h"
#import "UAPush+Internal.h"
#import "UAKeychainUtils+Internal.h"

@interface UAEventAPIClientTest : XCTestCase
@property (nonatomic, strong) id mockPush;
@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) id mockTimeZoneClass;
@property (nonatomic, strong) id mockLocaleClass;
@property (nonatomic, strong) id mockKeychainClass;

@property (nonatomic, strong) id mockSession;
@property (nonatomic, strong) UAConfig *config;
@property (nonatomic, strong) UAEventAPIClient *client;
@end

@implementation UAEventAPIClientTest

- (void)setUp {
    [super setUp];

    self.mockKeychainClass = [OCMockObject mockForClass:[UAKeychainUtils class]];
    [[[[self.mockKeychainClass stub] classMethod] andReturn:@"some-device-ID"] getDeviceID];

    self.mockLocaleClass = [OCMockObject mockForClass:[NSLocale class]];
    self.mockTimeZoneClass = [OCMockObject mockForClass:[NSTimeZone class]];

    self.mockPush = [OCMockObject niceMockForClass:[UAPush class]];

    self.mockAirship = [OCMockObject niceMockForClass:[UAirship class]];
    [[[self.mockAirship stub] andReturn:self.mockAirship] shared];
    [[[self.mockAirship stub] andReturn:self.mockPush] push];

    self.config = [UAConfig config];
    self.mockSession = [OCMockObject niceMockForClass:[UARequestSession class]];
    self.client = [UAEventAPIClient clientWithConfig:self.config session:self.mockSession];
}

- (void)tearDown {
    [self.mockPush stopMocking];
    [self.mockAirship stopMocking];
    [self.mockTimeZoneClass stopMocking];
    [self.mockLocaleClass stopMocking];
    [self.mockSession stopMocking];
    [self.mockKeychainClass stopMocking];

    [super tearDown];
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
    [[[self.mockPush stub] andReturn:channelIDString] channelID];

    // Opted in for both notifications and background push
    [[[self.mockPush stub] andReturnValue:OCMOCK_VALUE(YES)] userPushNotificationsAllowed];
    [[[self.mockPush stub] andReturnValue:OCMOCK_VALUE(YES)] backgroundPushNotificationsAllowed];

    // Timezone
    NSTimeZone *timeZone = [[NSTimeZone alloc] initWithName:@"America/New_York"];
    [[[self.mockTimeZoneClass stub] andReturn:timeZone] defaultTimeZone];

    // Locale
    NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    [[[self.mockLocaleClass stub] andReturn:locale] currentLocale];

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
            request.headers[@"X-UA-Channel-Background-Enabled"]) {

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

    [self waitForExpectationsWithTimeout:10 handler:nil];
}





@end
