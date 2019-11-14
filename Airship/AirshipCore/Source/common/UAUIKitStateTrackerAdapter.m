/* Copyright Airship and Contributors */

#import "UAUIKitStateTrackerAdapter+Internal.h"

@interface UAUIKitStateTrackerAdapter ()
@property (nonatomic, strong) UIApplication *application;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@end

@implementation UAUIKitStateTrackerAdapter

@synthesize stateTrackerDelegate;

- (instancetype)initWithApplication:(UIApplication *)application
                 notificationCenter:(NSNotificationCenter *)notificationCenter {
    self = [super init];

    if (self) {
        self.application = application;
        self.notificationCenter = notificationCenter;
        [self observeStateEvents];
    }

    return self;
}

+ (instancetype)adapterWithApplication:(UIApplication *)application
                    notificationCenter:(NSNotificationCenter *)notificationCenter {
    return [[self alloc] initWithApplication:application notificationCenter:notificationCenter];
}

+ (instancetype)adapter {
    return [[self alloc] initWithApplication:[UIApplication sharedApplication] notificationCenter:[NSNotificationCenter defaultCenter]];
}

- (void)observeStateEvents {
    [self.notificationCenter addObserver:self
                                selector:@selector(applicationDidFinishLaunching:)
                                    name:UIApplicationDidFinishLaunchingNotification
                                  object:nil];

    // active
    [self.notificationCenter addObserver:self
                                selector:@selector(applicationDidBecomeActive)
                                    name:UIApplicationDidBecomeActiveNotification
                                  object:nil];

    // inactive
    [self.notificationCenter addObserver:self
                                selector:@selector(applicationWillResignActive)
                                    name:UIApplicationWillResignActiveNotification
                                  object:nil];

    // foreground
    [self.notificationCenter addObserver:self
                                selector:@selector(applicationWillEnterForeground)
                                    name:UIApplicationWillEnterForegroundNotification
                                  object:nil];

    // background
    [self.notificationCenter addObserver:self
                                selector:@selector(applicationDidEnterBackground)
                                    name:UIApplicationDidEnterBackgroundNotification
                                  object:nil];


    [self.notificationCenter addObserver:self
                                selector:@selector(applicationWillTerminate)
                                    name:UIApplicationWillTerminateNotification
                                  object:nil];


}

- (UAApplicationState)state {
    switch (self.application.applicationState) {
        case UIApplicationStateActive:
            return UAApplicationStateActive;
        case UIApplicationStateInactive:
            return UAApplicationStateInactive;
        case UIApplicationStateBackground:
            return UAApplicationStateBackground;
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSDictionary *remoteNotification = nil;
#if !TARGET_OS_TV    // UIApplicationLaunchOptionsRemoteNotificationKey not available on tvOS
    remoteNotification = notification.userInfo[UIApplicationLaunchOptionsRemoteNotificationKey];
#endif

    [self.stateTrackerDelegate applicationDidFinishLaunching:remoteNotification];
}

- (void)applicationDidBecomeActive {
    [self.stateTrackerDelegate applicationDidBecomeActive];
}

- (void)applicationWillEnterForeground {
    [self.stateTrackerDelegate applicationWillEnterForeground];
}

- (void)applicationDidEnterBackground {
    [self.stateTrackerDelegate applicationDidEnterBackground];
}

- (void)applicationWillTerminate {
    [self.stateTrackerDelegate applicationWillTerminate];
}

- (void)applicationWillResignActive {
    [self.stateTrackerDelegate applicationWillResignActive];
}

@end
