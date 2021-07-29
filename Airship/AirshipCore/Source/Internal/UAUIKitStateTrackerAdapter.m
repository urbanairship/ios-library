/* Copyright Airship and Contributors */

#import "UAUIKitStateTrackerAdapter+Internal.h"

@interface UAUIKitStateTrackerAdapter ()
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@property (nonatomic, strong) UADispatcher *dispatcher;
@end

@implementation UAUIKitStateTrackerAdapter

@synthesize stateTrackerDelegate;

- (instancetype)initWithNotificationCenter:(NSNotificationCenter *)notificationCenter dispatcher:(UADispatcher *)dispatcher {
    self = [super init];

    if (self) {
        self.notificationCenter = notificationCenter;
        self.dispatcher = dispatcher;
        [self observeStateEvents];
    }

    return self;
}

+ (instancetype)adapterWithNotificationCenter:(NSNotificationCenter *)notificationCenter dispatcher:(UADispatcher *)dispatcher {
    return [[self alloc] initWithNotificationCenter:notificationCenter dispatcher:dispatcher];
}

+ (instancetype)adapter {
    return [[self alloc] initWithNotificationCenter:[NSNotificationCenter defaultCenter] dispatcher:[UADispatcher mainDispatcher]];
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

- (UAApplicationState)state NS_EXTENSION_UNAVAILABLE("Method not available in app extensions") {
    __block UAApplicationState result;
    [self.dispatcher doSync:^{
        switch ([UIApplication sharedApplication].applicationState) {
            case UIApplicationStateActive:
                result = UAApplicationStateActive;
                break;
            case UIApplicationStateInactive:
                result = UAApplicationStateInactive;
                break;
            case UIApplicationStateBackground:
                result = UAApplicationStateBackground;
        }
    }];

    return result;

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
