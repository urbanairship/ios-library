/* Copyright 2017 Urban Airship and Contributors */

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "UAConfig.h"
#import "UAChannelCapture+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAPush.h"
#import "UA_Base64.h"


@interface UAChannelCaptureTest : XCTestCase
@property(nonatomic, strong) UAConfig *config;
@property(nonatomic, strong) UAChannelCapture *channelCapture;
@property(nonatomic, strong) UAPreferenceDataStore *dataStore;

// REVISIT: convert to UIAlertController
@property(nonatomic, strong) id mockAlertView;
@property(nonatomic, strong) id mockPush;
@property(nonatomic, strong) id mockPasteboard;
@property(nonatomic, strong) id mockApplication;
@property(nonatomic, strong) id mockWindow;
@property(nonatomic, strong) id mockRootViewController;
@end

@implementation UAChannelCaptureTest

- (void)setUp {
    [super setUp];

    self.mockPush = [OCMockObject niceMockForClass:[UAPush class]];
    [[[self.mockPush stub] andReturn:@"pushChannelID"] channelID];

    self.mockPasteboard = [OCMockObject niceMockForClass:[UIPasteboard class]];
    [[[self.mockPasteboard stub] andReturn:self.mockPasteboard] generalPasteboard];


    self.mockRootViewController = [OCMockObject niceMockForClass:[UIViewController class]];
    self.mockWindow = [OCMockObject niceMockForClass:[UIWindow class]];
    [[[self.mockWindow stub] andReturn:self.mockRootViewController] rootViewController];

    self.mockApplication = [OCMockObject niceMockForClass:[UIApplication class]];
    [[[self.mockApplication stub] andReturn:self.mockApplication] sharedApplication];
    [[[self.mockApplication stub] andReturn:@[self.mockWindow]] windows];

    self.config = [UAConfig config];
    self.config.developmentAppKey = @"App key";
    self.config.developmentAppSecret = @"App secret";
    self.config.inProduction = NO;
    
    self.dataStore = [UAPreferenceDataStore preferenceDataStoreWithKeyPrefix:@"test.channelCapture"];

    self.channelCapture = [UAChannelCapture channelCaptureWithConfig:self.config
                                                                push:self.mockPush
                                                           dataStore:self.dataStore];
}

- (void)tearDown {
    [self.mockPush stopMocking];
    [self.mockRootViewController stopMocking];
    [self.mockWindow stopMocking];
    [self.mockPasteboard stopMocking];
    [self.mockApplication stopMocking];
    [self.channelCapture disable];

    [super tearDown];
}

/**
 * Test app foregrounding with the expected token in the pasteboard.
 */
- (void)testAppForeground {
    __block XCTestExpectation *alertDisplayed = [self expectationWithDescription:@"Alert displayed"];
    __block UIAlertController *alertController;

    // Generate a token with a URL
    [[[self.mockPasteboard stub] andReturn:[self generateTokenWithURLString:@"oh/hi?channel=CHANNEL"]] string];

    // We get a warning when we mock the init method
    [[self.mockRootViewController expect] presentViewController:[OCMArg checkWithBlock:^BOOL(id obj) {

        if (![obj isKindOfClass:[UIAlertController class]]) {
            return NO;
        }

        alertController = (UIAlertController *)obj;
        if (![alertController.title isEqualToString:@"Channel ID"]) {
            return NO;
        }

        if (![alertController.message isEqualToString:@"pushChannelID"]) {
            return NO;
        }

        if (alertController.actions.count != 3) {
            return NO;
        }

        [alertDisplayed fulfill];

        return YES;

    }] animated:YES completion:nil];

    // Post the foreground notification
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidBecomeActiveNotification
                                                        object:nil];

    // Wait for the test expectations
    [self waitForExpectationsWithTimeout:1 handler:^(NSError *error) {
        [self.mockRootViewController verify];
    }];
}

/**
 * Test app foregrounding with the expected token in the pasteboard without a URL.
 */
- (void)testAppForegroundNoURL {
    __block XCTestExpectation *alertDisplayed = [self expectationWithDescription:@"Alert displayed"];
    __block UIAlertController *alertController;

    // Generate a token with a URL
    [[[self.mockPasteboard stub] andReturn:[self generateTokenWithURLString:nil]] string];

    // We get a warning when we mock the init method
    [[self.mockRootViewController expect] presentViewController:[OCMArg checkWithBlock:^BOOL(id obj) {

        if (![obj isKindOfClass:[UIAlertController class]]) {
            return NO;
        }

        alertController = (UIAlertController *)obj;
        if (![alertController.title isEqualToString:@"Channel ID"]) {
            return NO;
        }

        if (![alertController.message isEqualToString:@"pushChannelID"]) {
            return NO;
        }

        if (alertController.actions.count != 2) {
            return NO;
        }

        [alertDisplayed fulfill];

        return YES;

    }] animated:YES completion:nil];

    // Post the foreground notification
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidBecomeActiveNotification
                                                        object:nil];

    // Wait for the test expectations
    [self waitForExpectationsWithTimeout:1 handler:^(NSError *error) {
        [self.mockRootViewController verify];
    }];
}

/**
 * Test disabling channel capture.
 */
- (void)testDisable {
    [self.channelCapture enable:1000];
    [self.channelCapture disable];
    XCTAssertEqual([self.dataStore objectForKey:UAChannelCaptureEnabledKey], nil);
}

/**
 * Test enabling channel capture for set amount of time.
 */
- (void)testEnable {
    [self.channelCapture enable:1000];
    // Stored date should be in future.
    XCTAssertTrue([[self.dataStore objectForKey:UAChannelCaptureEnabledKey] compare:[NSDate date]] != NSOrderedAscending);
    [self.channelCapture disable];
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
