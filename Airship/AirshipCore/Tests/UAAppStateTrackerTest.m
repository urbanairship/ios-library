/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "AirshipTests-Swift.h"

@import AirshipCore;

@interface UAAppStateTrackerTest : UABaseTest
@property(nonatomic, strong) UAAppStateTracker *tracker;
@property(nonatomic, strong) id mockAdapter;
@property(nonatomic, strong) id mockNotificationCenter;
@end

@implementation UAAppStateTrackerTest

- (void)setUp {
    self.mockNotificationCenter = [self mockForClass:[NSNotificationCenter class]];
    self.mockAdapter = [self mockForProtocol:@protocol(UAAppStateTrackerAdapter)];
    [[[self.mockAdapter stub] andReturnValue:@(UAApplicationStateInactive)] state];
    [self createTracker];
}

- (void)tearDown {
    [self.mockNotificationCenter stopMocking];
    [super tearDown];
}

- (void)createTracker {
    self.tracker = [[UAAppStateTracker alloc] initWithNotificationCenter:self.mockNotificationCenter adapter:self.mockAdapter];
}

- (void)testDelegateSignup {
    [[self.mockAdapter expect] setStateTrackerDelegate:[OCMArg isKindOfClass:[UAAppStateTracker class]]];
    [self createTracker];
    [self.mockAdapter verify];
}

- (void)testApplicationDidBecomeActive {
    [[self.mockNotificationCenter expect] postNotificationName:UAAppStateTracker.didBecomeActiveNotification
                                                        object:nil];

    [self.tracker applicationDidBecomeActive];

    [self.mockNotificationCenter verify];
}

- (void)testApplicationDidTransitionToForeground {
    [self.tracker applicationDidEnterBackground];
    [self.tracker applicationWillEnterForeground];

    [[self.mockNotificationCenter expect] postNotificationName:UAAppStateTracker.didTransitionToForeground
                                                        object:nil];

    [self.tracker applicationDidBecomeActive];

    [self.mockNotificationCenter verify];
}

- (void)testApplicationDidTransitionToForegroundOnStart {
    [[self.mockNotificationCenter expect] postNotificationName:UAAppStateTracker.didTransitionToForeground
                                                        object:nil];

    [self.tracker applicationDidBecomeActive];

    [self.mockNotificationCenter verify];
}

- (void)testApplicationWillEnterForeground {
    [[self.mockNotificationCenter expect] postNotificationName:UAAppStateTracker.willEnterForegroundNotification
                                                        object:nil];

    [self.tracker applicationWillEnterForeground];

    [self.mockNotificationCenter verify];
}

- (void)testApplicationDidEnterBackground {
    [[self.mockNotificationCenter expect] postNotificationName:UAAppStateTracker.didEnterBackgroundNotification
                                                        object:nil];

    [self.tracker applicationDidEnterBackground];

    [self.mockNotificationCenter verify];
}

- (void)testApplicationDidTransitionToBackground {
    [self.tracker applicationDidBecomeActive];
    [self.tracker applicationWillResignActive];

    [[self.mockNotificationCenter expect] postNotificationName:UAAppStateTracker.didTransitionToBackground
                                                        object:nil];

    [self.tracker applicationDidEnterBackground];

    [self.mockNotificationCenter verify];
}

- (void)testApplicationWillResignActive {
    [[self.mockNotificationCenter expect] postNotificationName:UAAppStateTracker.willResignActiveNotification
                                                        object:nil];

    [self.tracker applicationWillResignActive];

    [self.mockNotificationCenter verify];
}

- (void)testApplicationWillTerminate {
    [[self.mockNotificationCenter expect] postNotificationName:UAAppStateTracker.willTerminateNotification
                                                        object:nil];

    [self.tracker applicationWillTerminate];

    [self.mockNotificationCenter verify];
}

@end
