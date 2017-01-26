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
#import "UAConfig.h"
#import "UAChannelCapture.h"
#import "UAPush.h"
#import "UA_Base64.h"


@interface UAChannelCaptureTest : XCTestCase
@property(nonatomic, strong) UAConfig *config;
@property(nonatomic, strong) UAChannelCapture *channelCapture;

@property(nonatomic, strong) id mockAlertView;
@property(nonatomic, strong) id mockPush;
@property(nonatomic, strong) id mockPasteboard;
@property(nonatomic, strong) id mockApplication;

@end

@implementation UAChannelCaptureTest

- (void)setUp {
    [super setUp];

    self.mockPush = [OCMockObject niceMockForClass:[UAPush class]];
    [[[self.mockPush stub] andReturn:@"pushChannelID"] channelID];

    self.mockAlertView = [OCMockObject niceMockForClass:[UIAlertView class]];
    [[[self.mockAlertView stub] andReturn:self.mockAlertView] alloc];

    self.mockPasteboard = [OCMockObject niceMockForClass:[UIPasteboard class]];
    [[[self.mockPasteboard stub] andReturn:self.mockPasteboard] generalPasteboard];

    self.mockApplication = [OCMockObject niceMockForClass:[UIApplication class]];
    [[[self.mockApplication stub] andReturn:self.mockApplication] sharedApplication];


    self.config = [UAConfig config];
    self.config.developmentAppKey = @"App key";
    self.config.developmentAppSecret = @"App secret";
    self.config.inProduction = NO;

    self.channelCapture = [UAChannelCapture channelCaptureWithConfig:self.config push:self.mockPush];
}

- (void)tearDown {
    [self.mockPush stopMocking];
    [self.mockAlertView stopMocking];
    [self.mockPasteboard stopMocking];
    [self.mockApplication stopMocking];

    [super tearDown];
}

/**
 * Test app foregrounding with the expected token in the pasteboard.
 */
- (void)testAppForeground {
    XCTestExpectation *alertViewDisplayed = [self expectationWithDescription:@"Alert view displayed"];

    // Generate a token with a URL
    [[[self.mockPasteboard stub] andReturn:[self generateTokenWithURLString:@"oh/hi?channel=CHANNEL"]] string];

    // We get a warning when we mock the init method
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-value"
    [[[self.mockAlertView expect] andReturn:self.mockAlertView] initWithTitle:@"Channel ID"
                                                                      message:@"pushChannelID"
                                                                     delegate:self.channelCapture
                                                            cancelButtonTitle:@"Cancel"
                                                            otherButtonTitles:@"Copy", @"Save", nil];
#pragma clang diagnostic pop

    // When we show the alert view fulfill the test expectation
    [[[self.mockAlertView stub] andDo:^(NSInvocation *args) {
        [alertViewDisplayed fulfill];
    }] show];


    // Post the foreground notification
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidBecomeActiveNotification
                                                        object:nil];

    // Wait for the test expectations
    [self waitForExpectationsWithTimeout:1 handler:^(NSError *error) {
        [self.mockAlertView verify];
    }];

    // Verify button 1 sets the pasteboard's String
    [[self.mockPasteboard expect] setString:@"pushChannelID"];
    [self.channelCapture alertView:self.mockAlertView didDismissWithButtonIndex:1];
    [self.mockPasteboard verify];

    // Verify button 2 tries to open the channel URL
    [[self.mockApplication expect] openURL:[NSURL URLWithString:@"https://go.urbanairship.com/oh/hi?channel=pushChannelID"]];
    [self.channelCapture alertView:self.mockAlertView didDismissWithButtonIndex:2];
    [self.mockApplication verify];
}

/**
 * Test app foregrounding with the expected token in the pasteboard without a URL.
 */
- (void)testAppForegroundNoURL {
    XCTestExpectation *alertViewDisplayed = [self expectationWithDescription:@"Alert view displayed"];

    // Generate a token without a URL
    [[[self.mockPasteboard stub] andReturn:[self generateTokenWithURLString:nil]] string];

    // We get a warning when we mock the init method
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-value"
    [[[self.mockAlertView expect] andReturn:self.mockAlertView] initWithTitle:@"Channel ID"
                                                                      message:@"pushChannelID"
                                                                     delegate:self.channelCapture
                                                            cancelButtonTitle:@"Cancel"
                                                            otherButtonTitles:@"Copy", nil, nil];
#pragma clang diagnostic pop

    // When we show the alert view fulfill the test expectation
    [[[self.mockAlertView stub] andDo:^(NSInvocation *args) {
        [alertViewDisplayed fulfill];
    }] show];

    // Post the foreground notification
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidBecomeActiveNotification
                                                        object:nil];

    // Wait for the test expectations
    [self waitForExpectationsWithTimeout:1 handler:^(NSError *error) {
        [self.mockAlertView verify];
    }];

    // Verify button 1 sets the pasteboard's String
    [[self.mockPasteboard expect] setString:@"pushChannelID"];
    [self.channelCapture alertView:self.mockAlertView didDismissWithButtonIndex:1];
    [self.mockPasteboard verify];
}


/**
 * Helper method to generate the expected channel capture token.
 *
 * @param url Optional URL string.
 * @return The expected channel capture token.
 */
- (NSString *)generateTokenWithURLString:(NSString *)url {
    const char *keyCStr = [self.config.appKey cStringUsingEncoding:NSASCIIStringEncoding];
    size_t keyCstrLen = strlen(keyCStr);

    const char *secretCStr = [self.config.appSecret cStringUsingEncoding:NSASCIIStringEncoding];
    size_t secretCstrLen = strlen(secretCStr);

    NSMutableString *token = [NSMutableString string];
    for (size_t i = 0; i < keyCstrLen; i++) {
        [token appendFormat:@"%02x", (int)(keyCStr[i] ^ secretCStr[i % secretCstrLen])];
    }

    if (url) {
        [token appendString:url];
    }

    return UA_base64EncodedStringFromData([token dataUsingEncoding:NSUTF8StringEncoding]);
}



@end
