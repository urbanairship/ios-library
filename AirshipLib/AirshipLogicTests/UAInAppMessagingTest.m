
#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "UAInAppMessaging+Internal.h"
#import "UAInAppmessage.h"
#import "UAInAppMessageController.h"
#import "UAirship+Internal.h"
#import "UAPreferenceDataStore.h"

@interface UAInAppMessagingTest : XCTestCase
@property(nonatomic, strong) id mockAirship;
@property(nonatomic, strong) id mockDataStore;
@property(nonatomic, strong) id mockMessageController;
@property(nonatomic, strong) UAInAppMessaging *messaging;
@property(nonatomic, strong) UAInAppMessage *bannerMessage;
@property(nonatomic, strong) UAInAppMessage *nonBannerMessage;
@end

@implementation UAInAppMessagingTest

- (void)setUp {
    [super setUp];

    id mockDataStore = [OCMockObject niceMockForClass:[UAPreferenceDataStore class]];

    self.mockAirship = [OCMockObject niceMockForClass:[UAirship class]];
    [[[self.mockAirship stub] andReturn:self.mockAirship] shared];
    [[[self.mockAirship stub] andReturn:mockDataStore] dataStore];

    self.messaging = [[UAInAppMessaging alloc] init];

    id mockMessageController = [OCMockObject mockForClass:[UAInAppMessageController class]];
    self.mockMessageController = mockMessageController;

    self.messaging.messageControllerFactory = ^(UAInAppMessage *message) {
        return mockMessageController;
    };

    self.bannerMessage = [UAInAppMessage message];
    self.bannerMessage.alert = @"whatever";
    self.bannerMessage.displayType = UAInAppMessageDisplayTypeBanner;

    self.nonBannerMessage.alert = @"blah";
    self.nonBannerMessage.displayType = UAInAppMessageDisplayTypeUnknown;
}

- (void)tearDown {
    [super tearDown];
    [self.mockDataStore stopMocking];
    [self.mockAirship stopMocking];
}

/**
 * Test that banner messages are displayed
 */
- (void)testDisplayBannerMessage {
    [[self.mockMessageController expect] show];
    [self.messaging displayMessage:self.bannerMessage];
    [self.mockMessageController verify];
}

/**
 * Test that non-banner messages are not displayed.
 */
- (void)testDisplayNonBannerMessage {
    [self.messaging displayMessage:self.nonBannerMessage];
    [[self.mockMessageController reject] show];
    [self.mockMessageController verify];
}

/**
 * Test that banner messages are stored.
 */
- (void)testStoreBannerPendingMessage {
    [self.messaging storePendingMessage:self.bannerMessage];
    [[self.mockDataStore expect] setObject:self.bannerMessage.payload forKey:kUAPendingInAppMessageDataStoreKey];
    [self.mockDataStore verify];
}

/**
 * Test that non-banner messages are not stored.
 */
- (void)testStoreNonBannerPendingMessage {
    [self.messaging storePendingMessage:self.nonBannerMessage];
    [[self.mockDataStore reject] setObject:self.bannerMessage.payload forKey:kUAPendingInAppMessageDataStoreKey];
    [self.mockDataStore verify];
}

@end
