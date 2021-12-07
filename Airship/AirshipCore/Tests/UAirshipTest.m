
#import <UIKit/UIKit.h>
#import "UABaseTest.h"
#import "UAComponent.h"
#import "AirshipTests-Swift.h"

@import AirshipCore;

@interface UAirshipTest : UABaseTest
@property(nonatomic, strong) UATestAirshipInstance *airshipInstance;
@end

@interface UAirship()
- (bool) handleAirshipDeeplink:(NSURL *)deeplink;
@end

@implementation UAirshipTest

- (void)setUp {
    [super setUp];
    self.airshipInstance = [[UATestAirshipInstance alloc] init];
    [self.airshipInstance makeShared];
}

- (void)testUAirshipDeepLinks {
    // App Settings deeplink
    NSURL *deepLink = [NSURL URLWithString:@"uairship://app_settings"];
    
    id component = [self mockForProtocol:@protocol(UAComponent)];
    [[component reject] deepLink:deepLink];
    
    XCTestExpectation *deepLinked = [self expectationWithDescription:@"Deep linked"];
    [[UAirship shared] deepLink:deepLink completionHandler:^(BOOL result) {
        XCTAssertTrue(result);
        [deepLinked fulfill];
    }];
    
    // Wait for the test expectations
    [self waitForTestExpectations];
    
    [component verify];
    XCTAssertTrue([[UAirship shared] handleAirshipDeeplink:deepLink]);
    
    
    // App Store deeplink
    deepLink = [NSURL URLWithString:@"uairship://app_store?itunesID=0123456789"];
    
    component = [self mockForProtocol:@protocol(UAComponent)];
    [[component reject] deepLink:deepLink];
    
    deepLinked = [self expectationWithDescription:@"Deep linked"];
    [[UAirship shared] deepLink:deepLink completionHandler:^(BOOL result) {
        XCTAssertTrue(result);
        [deepLinked fulfill];
    }];
    
    // Wait for the test expectations
    [self waitForTestExpectations];
    
    [component verify];
    XCTAssertTrue([[UAirship shared] handleAirshipDeeplink:deepLink]);
}

- (void)testUAirshipComponentsDeepLinks {
    NSURL *deepLink = [NSURL URLWithString:@"uairship://some-deep-link"];
    id component1 = [self mockForProtocol:@protocol(UAComponent)];
    id component2 = [self mockForProtocol:@protocol(UAComponent)];
    id component3 = [self mockForProtocol:@protocol(UAComponent)];
    
    [[[component1 expect] andReturnValue:@(NO)] deepLink:deepLink];
    [[[component2 expect] andReturnValue:@(YES)] deepLink:deepLink];
    [[component3 reject] deepLink:deepLink];

    self.airshipInstance.components = @[component1, component2, component3];
    
    XCTestExpectation *deepLinked = [self expectationWithDescription:@"Deep linked"];
    [[UAirship shared] deepLink:deepLink completionHandler:^(BOOL result) {
        XCTAssertTrue(result);
        [deepLinked fulfill];
    }];
    
    // Wait for the test expectations
    [self waitForTestExpectations];
    
    [component1 verify];
    [component2 verify];
    [component3 verify];
}

- (void)testUAirshipComponentsDeepLinksAlwaysReturnsTrue {
    NSURL *deepLink = [NSURL URLWithString:@"uairship://some-deep-link"];
    id component1 = [self mockForProtocol:@protocol(UAComponent)];
    id component2 = [self mockForProtocol:@protocol(UAComponent)];
    
    [[[component1 expect] andReturnValue:@(NO)] deepLink:deepLink];
    [[[component2 expect] andReturnValue:@(NO)] deepLink:deepLink];

    self.airshipInstance.components = @[component1, component2];

    XCTestExpectation *deepLinked = [self expectationWithDescription:@"Deep linked"];
    [[UAirship shared] deepLink:deepLink completionHandler:^(BOOL result) {
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
    id component1 = [self mockForProtocol:@protocol(UAComponent)];
    [[component1 reject] deepLink:deepLink];

    id mockDelegate = [self mockForProtocol:@protocol(UADeepLinkDelegate)];
    [[[mockDelegate expect] andDo:^(NSInvocation *invocation) {
        void (^completionHandler)(void);
        [invocation getArgument:&completionHandler atIndex:3];
        completionHandler();
    }] receivedDeepLink:deepLink completionHandler:OCMOCK_ANY];
    
    self.airshipInstance.components = @[component1];
    [UAirship shared].deepLinkDelegate = mockDelegate;
    
    XCTestExpectation *deepLinked = [self expectationWithDescription:@"Deep linked"];
    [[UAirship shared] deepLink:deepLink completionHandler:^(BOOL result) {
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
    
    XCTestExpectation *deepLinked = [self expectationWithDescription:@"Deep linked"];
    [[UAirship shared] deepLink:deepLink completionHandler:^(BOOL result) {
        XCTAssertFalse(result);
        [deepLinked fulfill];
    }];
    
    // Wait for the test expectations
    [self waitForTestExpectations];
}

@end
