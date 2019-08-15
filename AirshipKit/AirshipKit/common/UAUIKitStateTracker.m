/* Copyright Airship and Contributors */

#import "UAUIKitStateTracker+Internal.h"

@interface UAUIKitStateTracker ()
@property (nonatomic, strong) UIApplication *application;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@property (nonatomic, assign) BOOL hasTransitionedFromBackground;
@end

@implementation UAUIKitStateTracker

@synthesize stateTrackerDelegate;

- (instancetype)initWithApplication:(UIApplication *)application
                 notificationCenter:(NSNotificationCenter *)notificationCenter {
    self = [super init];

    if (self) {
        self.application = application;
        self.notificationCenter = notificationCenter;
        self.hasTransitionedFromBackground = self.application.applicationState == UIApplicationStateActive;

        [self observeStateEvents];
    }

    return self;
}

+ (instancetype)trackerWithApplication:(UIApplication *)application
                    notificationCenter:(NSNotificationCenter *)notificationCenter {
    return [[self alloc] initWithApplication:application notificationCenter:notificationCenter];
}

- (void)observeStateEvents {
    [self.notificationCenter addObserver:self
                                selector:@selector(applicationDidFinishLaunching:)
                                    name:UIApplicationDidFinishLaunchingNotification
                                  object:nil];

    [self.notificationCenter addObserver:self
                                selector:@selector(applicationDidBecomeActive)
                                    name:UIApplicationDidBecomeActiveNotification
                                  object:nil];

    [self.notificationCenter addObserver:self
                                selector:@selector(applicationWillEnterForeground)
                                    name:UIApplicationWillEnterForegroundNotification
                                  object:nil];

    [self.notificationCenter addObserver:self
                                selector:@selector(applicationDidEnterBackground)
                                    name:UIApplicationDidEnterBackgroundNotification
                                  object:nil];

    [self.notificationCenter addObserver:self
                                selector:@selector(applicationWillTerminate)
                                    name:UIApplicationWillTerminateNotification
                                  object:nil];

    [self.notificationCenter addObserver:self
                                selector:@selector(applicationWillResignActive)
                                    name:UIApplicationWillResignActiveNotification
                                  object:nil];
}

- (UAApplicationState)uaState:(UIApplicationState)uiState {
    switch (uiState) {
        case UIApplicationStateActive:
            return UAApplicationStateActive;
        case UIApplicationStateInactive:
            return UAApplicationStateInactive;
        case UIApplicationStateBackground:
            return UAApplicationStateBackground;
    }
}

- (UAApplicationState)state {
    return [self uaState:self.application.applicationState];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    if ([self.stateTrackerDelegate respondsToSelector:@selector(applicationDidFinishLaunching:)]) {
        NSDictionary *remoteNotification;
#if !TARGET_OS_TV    // UIApplicationLaunchOptionsRemoteNotificationKey not available on tvOS
        remoteNotification = [notification.userInfo objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
#endif
        [self.stateTrackerDelegate applicationDidFinishLaunching:remoteNotification];
    }
}

- (void)applicationDidBecomeActive {
    if ([self.stateTrackerDelegate respondsToSelector:@selector(applicationDidBecomeActive)]) {
        [self.stateTrackerDelegate applicationDidBecomeActive];
    }

    if (!self.hasTransitionedFromBackground) {
        if ([self.stateTrackerDelegate respondsToSelector:@selector(applicationDidTransitionToForeground)]) {
            [self.stateTrackerDelegate applicationDidTransitionToForeground];
        }

        self.hasTransitionedFromBackground = YES;
    }
}

- (void)applicationWillEnterForeground {
    if ([self.stateTrackerDelegate respondsToSelector:@selector(applicationWillEnterForeground)]) {
        [self.stateTrackerDelegate applicationWillEnterForeground];
    }
}

- (void)applicationDidEnterBackground {
    self.hasTransitionedFromBackground = NO;

    if ([self.stateTrackerDelegate respondsToSelector:@selector(applicationDidEnterBackground)]) {
        [self.stateTrackerDelegate applicationDidEnterBackground];
    }
}

- (void)applicationWillTerminate {
    if ([self.stateTrackerDelegate respondsToSelector:@selector(applicationWillTerminate)]) {
        [self.stateTrackerDelegate applicationWillTerminate];
    }
}

- (void)applicationWillResignActive {
    if ([self.stateTrackerDelegate respondsToSelector:@selector(applicationWillResignActive)]) {
        [self.stateTrackerDelegate applicationWillResignActive];
    }
}

@end
