/* Copyright Airship and Contributors */

#import "UAUIKitStateTrackerAdapter+Internal.h"

@interface UAUIKitStateTrackerAdapter ()
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@end

@implementation UAUIKitStateTrackerAdapter

@synthesize stateTrackerDelegate;

- (instancetype)initWithNotificationCenter:(NSNotificationCenter *)notificationCenter {
    self = [super init];

    if (self) {
        self.notificationCenter = notificationCenter;
        [self observeStateEvents];
    }

    return self;
}

+ (instancetype)adapterWithNotificationCenter:(NSNotificationCenter *)notificationCenter {
    return [[self alloc] initWithNotificationCenter:notificationCenter];
}

+ (instancetype)adapter {
    return [[self alloc] initWithNotificationCenter:[NSNotificationCenter defaultCenter]];
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
    switch ([UIApplication sharedApplication].applicationState) {
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
