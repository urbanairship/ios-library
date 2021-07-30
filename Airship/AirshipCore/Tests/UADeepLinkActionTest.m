/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UAirship+Internal.h"
#import "UAActionResult.h"
#import "UAActionArguments.h"

@import AirshipCore;

@interface UADeepLinkActionTest : UABaseTest
@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) UADeepLinkAction *action;
@end

@implementation UADeepLinkActionTest

- (void)setUp {
    [super setUp];

    self.mockAirship = [self mockForClass:[UAirship class]];
    [UAirship setSharedAirship:self.mockAirship];

    self.action = [[UADeepLinkAction alloc] init];
}

/**
 * Test deep link action calls the delegate
 */
- (void)testPerformAirshipHandlesDeepLink {
    NSURL *url = [NSURL URLWithString:@"http://some-deep-link"];
    id arg = [UAActionArguments argumentsWithValue: @"http://some-deep-link" withSituation:UASituationManualInvocation];

    [[[self.mockAirship expect] andDo:^(NSInvocation *invocation) {
        void (^completionHandler)(BOOL);
        [invocation getArgument:&completionHandler atIndex:3];
        completionHandler(YES);
    }] deepLink:url completionHandler:OCMOCK_ANY];

    XCTestExpectation *actionFinished = [self expectationWithDescription:@"action finished"];
    [self.action performWithArguments:arg completionHandler:^(UAActionResult *result) {
        [actionFinished fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockAirship verify];
}

/**
 * Test that URLs that are not allowed will generate an error if the airship does not handle the deep link.
 */
- (void)testURLAllowListFallback {
    NSURL *url = [NSURL URLWithString:@"http://some-deep-link"];

    id arg = [UAActionArguments argumentsWithValue:url withSituation:UASituationManualInvocation];

    [[[self.mockAirship expect] andDo:^(NSInvocation *invocation) {
        void (^completionHandler)(BOOL);
        [invocation getArgument:&completionHandler atIndex:3];
        completionHandler(NO);
    }] deepLink:url completionHandler:OCMOCK_ANY];
    
    XCTestExpectation *actionFinished = [self expectationWithDescription:@"action finished"];
    [self.action performWithArguments:arg completionHandler:^(UAActionResult *result) {
        XCTAssertNotNil(result.error);
        [actionFinished fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockAirship verify];
}


/**
 * Test that strings are accepted.
 */
- (void)testAcceptsArgument {
    id arg = [UAActionArguments argumentsWithValue: @"http://some-deep-link" withSituation:UASituationManualInvocation];

    XCTAssertTrue([self.action acceptsArguments:arg]);
}


@end

