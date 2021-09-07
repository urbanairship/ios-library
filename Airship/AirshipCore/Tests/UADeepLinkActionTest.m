/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UAActionResult.h"
#import "UAActionArguments.h"
#import "AirshipTests-Swift.h"

@import AirshipCore;

@interface UADeepLinkActionTest : UABaseTest
@property(nonatomic, strong) UATestAirshipInstance *airship;
@property (nonatomic, strong) id stubURLAllowList;
@property (nonatomic, strong) UADeepLinkAction *action;
@end

@implementation UADeepLinkActionTest

- (void)setUp {
    [super setUp];

    self.stubURLAllowList = [[UAURLAllowList alloc] init];
    self.airship = [[UATestAirshipInstance alloc] init];
    self.airship.urlAllowList = self.stubURLAllowList;
    [self.airship makeShared];
    
    self.action = [[UADeepLinkAction alloc] init];
}

/**
 * Test deep link action calls the delegate
 */
- (void)testPerformAirshipHandlesDeepLink {
    NSURL *url = [NSURL URLWithString:@"http://some-deep-link"];
    id arg = [UAActionArguments argumentsWithValue: @"http://some-deep-link" withSituation:UASituationManualInvocation];

    id mockDelegate = [self mockForProtocol:@protocol(UADeepLinkDelegate)];
    [[[mockDelegate expect] andDo:^(NSInvocation *invocation) {
                void (^completionHandler)(void);
                [invocation getArgument:&completionHandler atIndex:3];
                completionHandler();
    }] receivedDeepLink:url completionHandler:OCMOCK_ANY];
    self.airship.deepLinkDelegate = mockDelegate;
    
    XCTestExpectation *actionFinished = [self expectationWithDescription:@"action finished"];
    [self.action performWithArguments:arg completionHandler:^(UAActionResult *result) {
        [actionFinished fulfill];
    }];

    [self waitForTestExpectations];
}

/**
 * Test that URLs that are not allowed will generate an error if the airship does not handle the deep link.
 */
- (void)testURLAllowListFallback {
    NSURL *url = [NSURL URLWithString:@"http://some-deep-link"];
    id arg = [UAActionArguments argumentsWithValue:url withSituation:UASituationManualInvocation];
    
    XCTestExpectation *actionFinished = [self expectationWithDescription:@"action finished"];
    [self.action performWithArguments:arg completionHandler:^(UAActionResult *result) {
        XCTAssertNotNil(result.error);
        [actionFinished fulfill];
    }];

    [self waitForTestExpectations];
}

/**
 * Test that strings are accepted.
 */
- (void)testAcceptsArgument {
    id arg = [UAActionArguments argumentsWithValue: @"http://some-deep-link" withSituation:UASituationManualInvocation];

    XCTAssertTrue([self.action acceptsArguments:arg]);
}


@end

