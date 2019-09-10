/* Copyright Airship and Contributors */

#import "UAUIKitStateTracker+Internal.h"

@interface UAUIKitStateTracker ()
@property (nonatomic, strong) UIApplication *application;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@property (nonatomic, assign) BOOL isForegrounded;
@property (nonatomic, assign) BOOL isBackgrounded;
@end

@implementation UAUIKitStateTracker

@synthesize stateTrackerDelegate;

- (instancetype)initWithApplication:(UIApplication *)application
                 notificationCenter:(NSNotificationCenter *)notificationCenter {
    self = [super init];

    if (self) {
        self.application = application;
        self.notificationCenter = notificationCenter;
        self.isForegrounded = self.application.applicationState == UIApplicationStateActive;
        self.isBackgrounded = self.application.applicationState == UIApplicationStateBackground;

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
    id <UAAppStateTrackerDelegate> strongDelegate = self.stateTrackerDelegate;
    if ([strongDelegate respondsToSelector:@selector(applicationDidFinishLaunching:)]) {
        NSDictionary *remoteNotification;
#if !TARGET_OS_TV    // UIApplicationLaunchOptionsRemoteNotificationKey not available on tvOS
        remoteNotification = [notification.userInfo objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
#endif
        [strongDelegate applicationDidFinishLaunching:remoteNotification];
    }
}

- (void)applicationDidBecomeActive {
    self.isBackgrounded = NO;

    id <UAAppStateTrackerDelegate> strongDelegate = self.stateTrackerDelegate;

    if ([strongDelegate respondsToSelector:@selector(applicationDidBecomeActive)]) {
        [strongDelegate applicationDidBecomeActive];
    }

    if (!self.isForegrounded) {
        if ([strongDelegate respondsToSelector:@selector(applicationDidTransitionToForeground)]) {
            [strongDelegate applicationDidTransitionToForeground];
        }

        self.isForegrounded = YES;
    }
}

- (void)applicationWillEnterForeground {
    id <UAAppStateTrackerDelegate> strongDelegate = self.stateTrackerDelegate;

    if ([strongDelegate respondsToSelector:@selector(applicationWillEnterForeground)]) {
        [strongDelegate applicationWillEnterForeground];
    }
}

- (void)applicationDidEnterBackground {
    self.isForegrounded = NO;

    id <UAAppStateTrackerDelegate> strongDelegate = self.stateTrackerDelegate;

    if ([strongDelegate respondsToSelector:@selector(applicationDidEnterBackground)]) {
        [strongDelegate applicationDidEnterBackground];
    }

    if (!self.isBackgrounded) {
        if ([strongDelegate respondsToSelector:@selector(applicationDidTransitionToBackground)]) {
            [strongDelegate applicationDidTransitionToBackground];
        }

        self.isBackgrounded = YES;
    }
}

- (void)applicationWillTerminate {
    id <UAAppStateTrackerDelegate> strongDelegate = self.stateTrackerDelegate;

    if ([strongDelegate respondsToSelector:@selector(applicationWillTerminate)]) {
        [strongDelegate applicationWillTerminate];
    }
}

- (void)applicationWillResignActive {
    id <UAAppStateTrackerDelegate> strongDelegate = self.stateTrackerDelegate;

    if ([strongDelegate respondsToSelector:@selector(applicationWillResignActive)]) {
        [strongDelegate applicationWillResignActive];
    }
}

@end
