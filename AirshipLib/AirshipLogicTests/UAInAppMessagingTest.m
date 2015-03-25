
#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "UAInAppMessaging+Internal.h"
#import "UAInAppmessage.h"
#import "UAInAppMessageController.h"
#import "UAirship+Internal.h"
#import "UAPreferenceDataStore.h"
#import "UAPush.h"
#import "UAAnalytics.h"

@interface UAInAppMessagingTest : XCTestCase
@property(nonatomic, strong) id mockDataStore;
@property(nonatomic, strong) id mockAnalytics;
@property(nonatomic, strong) id mockPush;
@property(nonatomic, strong) id mockMessageController;

@property(nonatomic, strong) UAInAppMessage *bannerMessage;
@property(nonatomic, strong) UAInAppMessage *nonBannerMessage;
@property(nonatomic, strong) UAInAppMessaging *inAppMessaging;

@end

@implementation UAInAppMessagingTest

- (void)setUp {
    [super setUp];

    id mockDataStore = [OCMockObject niceMockForClass:[UAPreferenceDataStore class]];
    id mockAnalytics = [OCMockObject niceMockForClass:[UAAnalytics class]];
    id mockPush = [OCMockObject niceMockForClass:[UAPush class]];


    self.inAppMessaging = [UAInAppMessaging inAppMessagingWithPush:mockPush analytics:mockAnalytics dataStore:mockDataStore];

    self.mockMessageController = [OCMockObject mockForClass:[UAInAppMessageController class]];
    [[[self.mockMessageController stub] andReturn:self.mockMessageController] controllerWithMessage:[OCMArg any] dismissalBlock:[OCMArg any]];

    self.bannerMessage = [UAInAppMessage message];
    self.bannerMessage.alert = @"whatever";
    self.bannerMessage.displayType = UAInAppMessageDisplayTypeBanner;

    self.nonBannerMessage.alert = @"blah";
    self.nonBannerMessage.displayType = UAInAppMessageDisplayTypeUnknown;
}

- (void)tearDown {
    [super tearDown];
    [self.mockDataStore stopMocking];
    [self.mockAnalytics stopMocking];
    [self.mockPush stopMocking];
    [self.mockMessageController stopMocking];

}

/**
 * Test that banner messages are displayed
 */
- (void)testDisplayBannerMessage {
    [[self.mockMessageController expect] show];

    [self.inAppMessaging displayMessage:self.bannerMessage];

    [self.mockMessageController verify];
}

/**
 * Test that non-banner messages are not displayed.
 */
- (void)testDisplayNonBannerMessage {
    [[self.mockMessageController reject] show];

    [self.inAppMessaging displayMessage:self.nonBannerMessage];

    [self.mockMessageController verify];
}

/**
 * Test that banner messages are stored.
 */
- (void)testStoreBannerPendingMessage {
    [[self.mockDataStore expect] setObject:self.bannerMessage.payload forKey:kUAPendingInAppMessageDataStoreKey];

    self.inAppMessaging.pendingMessage = self.bannerMessage;

    [self.mockDataStore verify];
}

/**
 * Test that non-banner messages are not stored.
 */
- (void)testStoreNonBannerPendingMessage {
    [[self.mockDataStore reject] setObject:self.bannerMessage.payload forKey:kUAPendingInAppMessageDataStoreKey];

    self.inAppMessaging.pendingMessage = self.nonBannerMessage;

    [self.mockDataStore verify];
}

@end
