/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UARuntimeConfig.h"
#import "UAChannelCapture+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAPush+Internal.h"
#import "UA_Base64.h"
#import "UAUtils.h"
#import "UATestDispatcher.h"

@interface UAChannelCaptureTest : UABaseTest
@property(nonatomic, strong) UAChannelCapture *channelCapture;

@property(nonatomic, strong) id mockChannel;
@property(nonatomic, strong) id mockPushProviderDelegate;
@property(nonatomic, strong) id mockPasteboard;
@property(nonatomic, strong) id mockAppStateTracker;
@property(nonatomic, strong) id mockUtils;
@property(nonatomic, strong) id mockWindow;
@property(nonatomic, strong) id mockRootViewController;
@end

@implementation UAChannelCaptureTest

- (void)setUp {
    [super setUp];

    self.mockChannel = [self mockForClass:[UAChannel class]];
    [[[self.mockChannel stub] andReturn:@"pushChannelID"] identifier];

    self.mockPushProviderDelegate = [self mockForProtocol:@protocol(UAPushProviderDelegate)];

    self.mockPasteboard = [self mockForClass:[UIPasteboard class]];
    [[[self.mockPasteboard stub] andReturn:self.mockPasteboard] generalPasteboard];

    self.mockRootViewController = [self mockForClass:[UIViewController class]];
    self.mockWindow = [self mockForClass:[UIWindow class]];
    [[[self.mockWindow stub] andReturn:self.mockRootViewController] rootViewController];

    self.mockUtils = [self mockForClass:[UAUtils class]];
    [[[self.mockUtils stub] andReturn:self.mockWindow] mainWindow];

    self.mockAppStateTracker = [self mockForProtocol:@protocol(UAAppStateTracker)];

    self.channelCapture = [UAChannelCapture channelCaptureWithConfig:self.config
                                                             channel:self.mockChannel
                                                pushProviderDelegate:self.mockPushProviderDelegate
                                                           dataStore:self.dataStore
                                                     appStateTracker:self.mockAppStateTracker
                                                      mainDispatcher:[UATestDispatcher testDispatcher]
                                                backgroundDispatcher:[UATestDispatcher testDispatcher]];
}

/**
 * Test channel capture tool with a token and URL.
 */
- (void)testChannelCapture {
    [self.channelCapture enable:1000];
    [[[self.mockPushProviderDelegate stub] andReturnValue:@(YES)] backgroundPushNotificationsAllowed];
    [self verifyChannelCaptureDisplayedWithUrl:@"oh/hi?channel=CHANNEL"];
}

/**
 * Test channel capture tool always works when backgorundPushNotificationsAllowed is NO.
 */
- (void)testChannelCaptureToolBackgroundRefreshDisabled {
    [[[self.mockPushProviderDelegate stub] andReturnValue:@(NO)] backgroundPushNotificationsAllowed];
    [self verifyChannelCaptureDisplayedWithUrl:@"oh/hi?channel=CHANNEL"];
}

/**
 * Test channel capture tool without a URL.
 */
- (void)testChannelCaptureNoTokenURL {
    [self.channelCapture enable:1000];
    [[[self.mockPushProviderDelegate stub] andReturnValue:@(NO)] backgroundPushNotificationsAllowed];
    [self verifyChannelCaptureDisplayedWithUrl:nil];
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

/**
 * Helper method to verify channel capture dialog
 */
- (void)verifyChannelCaptureDisplayedWithUrl:(NSString *)url {
    __block XCTestExpectation *alertDisplayed = [self expectationWithDescription:@"Alert displayed"];
    __block UIAlertController *alertController;

    // Generate a token with a URL
    [[[self.mockPasteboard stub] andReturn:[self generateTokenWithURLString:url]] string];
    [[[self.mockPasteboard stub] andReturnValue:@(YES)] hasStrings];

    // We get a warning when we mock the init method
    [[[self.mockRootViewController expect] andDo:^(NSInvocation *invocation) {
        [alertDisplayed fulfill];
    }] presentViewController:[OCMArg checkWithBlock:^BOOL(id obj) {
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

        if (url) {
            if (alertController.actions.count != 3) {
                return NO;
            }
        } else if (alertController.actions.count != 2) {
            return NO;
        }

        return YES;

    }] animated:YES completion:nil];

    [self.channelCapture applicationDidBecomeActive];

    // Wait for the test expectations
    [self waitForTestExpectations];
    [self.mockRootViewController verify];
}


@end

