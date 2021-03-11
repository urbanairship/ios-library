/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UAAppStateTracker+Internal.h"

@interface UAAppStateTrackerTest : UABaseTest
@property(nonatomic, strong) UAAppStateTracker *tracker;
@property(nonatomic, strong) id mockAdapter;
@property(nonatomic, strong) id mockNotificationCenter;
@end

@implementation UAAppStateTrackerTest

- (void)setUp {
    self.mockNotificationCenter = [self mockForClass:[NSNotificationCenter class]];
    self.mockAdapter = [self mockForProtocol:@protocol(UAAppStateTrackerAdapter)];

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

- (void)testApplicationDidFinishLaunching {
    id launchDict = @{@"foo" : @"bar"};

    [[self.mockNotificationCenter expect] postNotificationName:UAApplicationDidFinishLaunchingNotification
                                                        object:nil
                                                      userInfo:@{UAApplicationLaunchOptionsRemoteNotificationKey : launchDict}];

    [self.tracker applicationDidFinishLaunching:launchDict];
    [self.mockNotificationCenter verify];
}

- (void)testApplicationDidBecomeActive {
    [[self.mockNotificationCenter expect] postNotificationName:UAApplicationDidBecomeActiveNotification
                                                        object:nil];

    [self.tracker applicationDidBecomeActive];

    [self.mockNotificationCenter verify];
}

- (void)testApplicationDidTransitionToForeground {
    [self.tracker applicationDidEnterBackground];
    [self.tracker applicationWillEnterForeground];

    [[self.mockNotificationCenter expect] postNotificationName:UAApplicationDidTransitionToForeground
                                                        object:nil];

    [self.tracker applicationDidBecomeActive];

    [self.mockNotificationCenter verify];
}

- (void)testApplicationDidTransitionToForegroundOnStart {
    [[self.mockNotificationCenter expect] postNotificationName:UAApplicationDidTransitionToForeground
                                                        object:nil];

    [self.tracker applicationDidBecomeActive];

    [self.mockNotificationCenter verify];
}

- (void)testApplicationWillEnterForeground {
    [[self.mockNotificationCenter expect] postNotificationName:UAApplicationWillEnterForegroundNotification
                                                        object:nil];

    [self.tracker applicationWillEnterForeground];

    [self.mockNotificationCenter verify];
}

- (void)testApplicationDidEnterBackground {
    [[self.mockNotificationCenter expect] postNotificationName:UAApplicationDidEnterBackgroundNotification
                                                        object:nil];

    [self.tracker applicationDidEnterBackground];

    [self.mockNotificationCenter verify];
}

- (void)testApplicationDidTransitionToBackground {
    [self.tracker applicationDidBecomeActive];
    [self.tracker applicationWillResignActive];

    [[self.mockNotificationCenter expect] postNotificationName:UAApplicationDidTransitionToBackground
                                                        object:nil];

    [self.tracker applicationDidEnterBackground];

    [self.mockNotificationCenter verify];
}

- (void)testApplicationWillResignActive {
    [[self.mockNotificationCenter expect] postNotificationName:UAApplicationWillResignActiveNotification
                                                        object:nil];

    [self.tracker applicationWillResignActive];

    [self.mockNotificationCenter verify];
}

- (void)testApplicationWillTerminate {
    [[self.mockNotificationCenter expect] postNotificationName:UAApplicationWillTerminateNotification
                                                        object:nil];

    [self.tracker applicationWillTerminate];

    [self.mockNotificationCenter verify];
}

- (void)testState {
    XCTAssertEqual(UAApplicationStateActive, self.tracker.state);
    [[[self.mockAdapter stub] andReturnValue:@(UAApplicationStateInactive)] state];
    XCTAssertEqual(UAApplicationStateInactive, self.tracker.state);
}

@end
