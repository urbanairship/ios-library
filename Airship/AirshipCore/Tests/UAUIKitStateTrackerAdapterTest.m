/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UAUIKitStateTrackerAdapter+Internal.h"

@interface UAUIKitStateTrackerAdapterTest : UABaseTest
@property(nonatomic, strong) UAUIKitStateTrackerAdapter *adapter;
@property(nonatomic, strong) id mockApplication;
@property(nonatomic, strong) id mockDelegate;
@end

@implementation UAUIKitStateTrackerAdapterTest

- (void)setUp {
    self.mockApplication = [self mockForClass:[UIApplication class]];
    self.mockDelegate = [self mockForProtocol:@protocol(UAAppStateTrackerDelegate)];

    [self createAdapter];
}

- (void)createAdapter {
    self.adapter = [UAUIKitStateTrackerAdapter adapterWithApplication:self.mockApplication notificationCenter:[NSNotificationCenter defaultCenter]];
    self.adapter.stateTrackerDelegate = self.mockDelegate;
}

- (void)testActiveState {
    [[[self.mockApplication stub] andReturnValue:@(UIApplicationStateActive)] applicationState];
    XCTAssertEqual(self.adapter.state, UAApplicationStateActive);
}

- (void)testInactiveState {
    [[[self.mockApplication stub] andReturnValue:@(UIApplicationStateInactive)] applicationState];
    XCTAssertEqual(self.adapter.state, UAApplicationStateInactive);
}

- (void)testBackgroundState {
    [[[self.mockApplication stub] andReturnValue:@(UIApplicationStateBackground)] applicationState];
    XCTAssertEqual(self.adapter.state, UAApplicationStateBackground);
}

- (void)testApplicationDidFinishLaunching {
    id launchDict = @{@"foo" : @"bar"};
    id userInfo = @{UIApplicationLaunchOptionsRemoteNotificationKey : launchDict};

    [[self.mockDelegate expect] applicationDidFinishLaunching:launchDict];

    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidFinishLaunchingNotification
                                                        object:nil
                                                      userInfo:userInfo];
    [self.mockDelegate verify];
}

- (void)testApplicationDidBecomeActive {
    [[self.mockDelegate expect] applicationDidBecomeActive];

    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidBecomeActiveNotification
                                                        object:nil
                                                      userInfo:nil];
    [self.mockDelegate verify];
}

- (void)testApplicationWillEnterForeground {
    [[self.mockDelegate expect] applicationWillEnterForeground];

    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillEnterForegroundNotification
                                                        object:nil
                                                      userInfo:nil];
    [self.mockDelegate verify];
}

- (void)testApplicationDidEnterBackground {
    [[self.mockDelegate expect] applicationDidEnterBackground];

    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidEnterBackgroundNotification
                                                        object:nil
                                                      userInfo:nil];
    [self.mockDelegate verify];
}

- (void)testApplicationWillTerminate {
    [[self.mockDelegate expect] applicationWillTerminate];

    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillTerminateNotification
                                                        object:nil
                                                      userInfo:nil];
    [self.mockDelegate verify];
}

- (void)testApplicationWillResignActive {
    [[self.mockDelegate expect] applicationWillResignActive];

    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillResignActiveNotification
                                                        object:nil
                                                      userInfo:nil];
    [self.mockDelegate verify];
}

@end
