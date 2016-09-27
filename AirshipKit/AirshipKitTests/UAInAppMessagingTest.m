
#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "UAInAppMessaging+Internal.h"
#import "UAInAppmessage.h"
#import "UAInAppMessageController+Internal.h"
#import "UAirship+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAPush.h"
#import "UAAnalytics.h"

@interface UAInAppMessagingTest : XCTestCase
@property(nonatomic, strong) id mockAnalytics;
@property(nonatomic, strong) id mockMessageController;

@property(nonatomic, strong) UAPreferenceDataStore *dataStore;
@property(nonatomic, strong) UAInAppMessage *bannerMessage;
@property(nonatomic, strong) UAInAppMessage *nonBannerMessage;
@property(nonatomic, strong) UAInAppMessaging *inAppMessaging;

@end

@implementation UAInAppMessagingTest

- (void)setUp {
    [super setUp];

    self.dataStore = [UAPreferenceDataStore preferenceDataStoreWithKeyPrefix:@"UAInAppMessagingTest"];

    self.mockAnalytics = [OCMockObject niceMockForClass:[UAAnalytics class]];

    self.inAppMessaging = [UAInAppMessaging inAppMessagingWithAnalytics:self.mockAnalytics dataStore:self.dataStore];

    self.mockMessageController = [OCMockObject mockForClass:[UAInAppMessageController class]];
    [[[self.mockMessageController stub] andReturn:self.mockMessageController] controllerWithMessage:[OCMArg any] delegate:[OCMArg any] dismissalBlock:[OCMArg any]];

    self.bannerMessage = [UAInAppMessage message];
    self.bannerMessage.identifier = @"identifier";
    self.bannerMessage.alert = @"whatever";
    self.bannerMessage.displayType = UAInAppMessageDisplayTypeBanner;
    self.bannerMessage.expiry = [NSDate dateWithTimeIntervalSinceNow:10000];

    self.nonBannerMessage.alert = @"blah";
    self.nonBannerMessage.displayType = UAInAppMessageDisplayTypeUnknown;
}

- (void)tearDown {
    [self.mockAnalytics stopMocking];
    [self.mockMessageController stopMocking];

    [self.dataStore removeAll];

    [super tearDown];
}

/**
 * Test that banner messages are displayed
 */
- (void)testDisplayBannerMessage {
    [(UAInAppMessageController *)[self.mockMessageController expect] show];

    [self.inAppMessaging displayMessage:self.bannerMessage];

    [self.mockMessageController verify];
}

/**
 * Test that non-banner messages are not displayed.
 */
- (void)testDisplayNonBannerMessage {
    [(UAInAppMessageController *)[self.mockMessageController reject] show];

    [self.inAppMessaging displayMessage:self.nonBannerMessage];

    [self.mockMessageController verify];
}

/**
 * Test that banner messages are stored.
 */
- (void)testStoreBannerPendingMessage {
    self.inAppMessaging.pendingMessage = self.bannerMessage;

    XCTAssertEqualObjects(self.inAppMessaging.pendingMessage.payload, self.bannerMessage.payload);
}

/**
 * Test that non-banner messages are not stored.
 */
- (void)testStoreNonBannerPendingMessage {
    self.inAppMessaging.pendingMessage = self.nonBannerMessage;

    XCTAssertNil(self.inAppMessaging.pendingMessage);
}

/**
 * Test display pending message tries to display the pending message.
 */
- (void)testDisplayPendingMessage {
    self.inAppMessaging.pendingMessage = self.bannerMessage;

    // Expect to show the message
    [(UAInAppMessageController *)[self.mockMessageController expect] show];

    // Trigger the message to be displayed
    [self.inAppMessaging displayPendingMessage];

    // Verify we actually tried to show a message
    [self.mockMessageController verify];
}

/**
 * Test auto display enabled persists in the data store.
 */
- (void)testAutoDisplayEnabled {
    XCTAssertTrue(self.inAppMessaging.isAutoDisplayEnabled);

    self.inAppMessaging.autoDisplayEnabled = NO;
    XCTAssertFalse(self.inAppMessaging.isAutoDisplayEnabled);


    // Verify it persists
    self.inAppMessaging = [UAInAppMessaging inAppMessagingWithAnalytics:self.mockAnalytics dataStore:self.dataStore];
    XCTAssertFalse(self.inAppMessaging.isAutoDisplayEnabled);
}

/**
 * Test that an event is added only if the messge is actually displayed
 */
- (void)testSendDisplayEventIfDisplayed {
    [(UAInAppMessageController *)[[self.mockMessageController stub] andReturnValue:OCMOCK_VALUE(YES)] show];

    [[self.mockAnalytics expect] addEvent:[OCMArg any]];
    [self.inAppMessaging displayMessage:self.bannerMessage];

    [self. mockAnalytics verify];

    [(UAInAppMessageController *)[[self.mockMessageController stub] andReturnValue:OCMOCK_VALUE(NO)] show];
    [[self.mockAnalytics reject] addEvent:[OCMArg any]];
    [self. mockAnalytics verify];
}


@end
