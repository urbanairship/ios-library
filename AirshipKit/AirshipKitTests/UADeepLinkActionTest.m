/* Copyright 2017 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UADeepLinkAction.h"
#import "UAirship+Internal.h"

@interface UADeepLinkActionTest : UABaseTest
@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) id mockDelegate;
@property (nonatomic, strong) UADeepLinkAction *action;
@end

@implementation UADeepLinkActionTest

- (void)setUp {
    [super setUp];

    self.mockAirship = [self mockForClass:[UAirship class]];
    [[[self.mockAirship stub] andReturn:self.mockAirship] shared];

    self.mockDelegate = [self mockForProtocol:@protocol(UADeepLinkDelegate)];

    self.action = [[UADeepLinkAction alloc] init];
}

/**
 * Test deep link action calls the delegate
 */
- (void)testPerformWithDeepLinkDelegate {
    [[[self.mockAirship stub] andReturn:self.mockDelegate] deepLinkDelegate];

    NSURL *url = [NSURL URLWithString:@"http://some-deep-link"];
    id arg = [UAActionArguments argumentsWithValue: @"http://some-deep-link" withSituation:UASituationManualInvocation];

    [[[self.mockDelegate expect] andDo:^(NSInvocation *invocation) {
        void (^completionHandler)(void);
        [invocation getArgument:&completionHandler atIndex:3];
        completionHandler();
    }] receivedDeepLink:url completionHandler:OCMOCK_ANY];


    XCTestExpectation *actionFinished = [self expectationWithDescription:@"action finished"];
    [self.action performWithArguments:arg completionHandler:^(UAActionResult *result) {
        [actionFinished fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
    [self.mockDelegate verify];
}

/**
 * Test that URLs that are not whitelisted will generate an error if the delegate is not set.
 */
- (void)testWhiteListNoDelegate {
    id arg = [UAActionArguments argumentsWithValue: @"http://some-deep-link" withSituation:UASituationManualInvocation];

    XCTestExpectation *actionFinished = [self expectationWithDescription:@"action finished"];
    [self.action performWithArguments:arg completionHandler:^(UAActionResult *result) {
        XCTAssertNotNil(result.error);
        [actionFinished fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
    [self.mockDelegate verify];
}

@end

