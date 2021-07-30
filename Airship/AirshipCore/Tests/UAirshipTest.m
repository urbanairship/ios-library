
#import <UIKit/UIKit.h>
#import "UABaseTest.h"
#import "UAirship+Internal.h"
#import "UAConfig.h"
#import "UAComponent+Internal.h"

@interface UAirshipTest : UABaseTest
@end

@implementation UAirshipTest


/**
 * Test that if takeOff is called on a background thread that an exception is thrown.
 */
- (void)testExceptionForTakeOffOnNotTheMainThread {
    __block id config = [self mockForClass:[UAConfig class]];
    [[[config stub] andReturn:@YES] validate];

    XCTestExpectation *takeOffCalled = [self expectationWithDescription:@"Takeoff called"];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        XCTAssertThrowsSpecificNamed([UAirship takeOff:config],
                                     NSException, UAirshipTakeOffBackgroundThreadException,
                                     @"Calling takeOff on a background thread should throw a UAirshipTakeOffBackgroundThreadException");
        [takeOffCalled fulfill];
    });


    // Wait for the test expectations
    [self waitForTestExpectations];
}

- (void)testUAirshipDeepLinks {
    NSURL *deepLink = [NSURL URLWithString:@"uairship://some-deep-link"];
    id component1 = [self mockForClass:[UAComponent class]];
    id component2 = [self mockForClass:[UAComponent class]];
    id component3 = [self mockForClass:[UAComponent class]];
    
    [[[component1 expect] andReturnValue:@(NO)] deepLink:deepLink];
    [[[component2 expect] andReturnValue:@(YES)] deepLink:deepLink];
    [[component3 reject] deepLink:deepLink];

    UAirship *airship = [[UAirship alloc] init];
    airship.components = @[component1, component2, component3];
    
    XCTestExpectation *deepLinked = [self expectationWithDescription:@"Deep linked"];
    [airship deepLink:deepLink completionHandler:^(BOOL result) {
        XCTAssertTrue(result);
        [deepLinked fulfill];
    }];
    
    // Wait for the test expectations
    [self waitForTestExpectations];
    
    [component1 verify];
    [component2 verify];
    [component3 verify];
}

- (void)testUAirshipDeepLinksAlwaysReturnsTrue {
    NSURL *deepLink = [NSURL URLWithString:@"uairship://some-deep-link"];
    id component1 = [self mockForClass:[UAComponent class]];
    id component2 = [self mockForClass:[UAComponent class]];
    
    [[[component1 expect] andReturnValue:@(NO)] deepLink:deepLink];
    [[[component2 expect] andReturnValue:@(NO)] deepLink:deepLink];

    UAirship *airship = [[UAirship alloc] init];
    airship.components = @[component1, component2];
    
    XCTestExpectation *deepLinked = [self expectationWithDescription:@"Deep linked"];
    [airship deepLink:deepLink completionHandler:^(BOOL result) {
        XCTAssertTrue(result);
        [deepLinked fulfill];
    }];
    
    // Wait for the test expectations
    [self waitForTestExpectations];
    
    [component1 verify];
    [component2 verify];
}

- (void)testDeepLinkDelegate {
    NSURL *deepLink = [NSURL URLWithString:@"some-other://some-deep-link"];
    id component1 = [self mockForClass:[UAComponent class]];
    [[component1 reject] deepLink:deepLink];

    id mockDelegate = [self mockForProtocol:@protocol(UADeepLinkDelegate)];
    [[[mockDelegate expect] andDo:^(NSInvocation *invocation) {
        void (^completionHandler)(void);
        [invocation getArgument:&completionHandler atIndex:3];
        completionHandler();
    }] receivedDeepLink:deepLink completionHandler:OCMOCK_ANY];
    
    UAirship *airship = [[UAirship alloc] init];
    airship.components = @[component1];
    airship.deepLinkDelegate = mockDelegate;
    
    XCTestExpectation *deepLinked = [self expectationWithDescription:@"Deep linked"];
    [airship deepLink:deepLink completionHandler:^(BOOL result) {
        XCTAssertTrue(result);
        [deepLinked fulfill];
    }];
    
    // Wait for the test expectations
    [self waitForTestExpectations];
    
    [component1 verify];
    [mockDelegate verify];
}

- (void)testDeepLinkDelegateNotSet {
    NSURL *deepLink = [NSURL URLWithString:@"some-other://some-deep-link"];
    UAirship *airship = [[UAirship alloc] init];
    
    XCTestExpectation *deepLinked = [self expectationWithDescription:@"Deep linked"];
    [airship deepLink:deepLink completionHandler:^(BOOL result) {
        XCTAssertFalse(result);
        [deepLinked fulfill];
    }];
    
    // Wait for the test expectations
    [self waitForTestExpectations];
}

@end
