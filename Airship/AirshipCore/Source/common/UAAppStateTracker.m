/* Copyright Airship and Contributors */

#import "UAAppStateTracker.h"
#import "UAAppStateTrackerAdapter+Internal.h"
#import "UAUIKitStateTrackerAdapter+Internal.h"

NSNotificationName const UAApplicationDidFinishLaunchingNotification = @"com.urbanairship.applicaiton_did_finish_launching";
NSNotificationName const UAApplicationDidBecomeActiveNotification = @"com.urbanairship.application_did_become_active";
NSNotificationName const UAApplicationWillEnterForegroundNotification = @"com.urbanairship.application_will_enter_foreground";
NSNotificationName const UAApplicationDidEnterBackgroundNotification = @"com.urbanairship.application_did_enter_background";
NSNotificationName const UAApplicationWillResignActiveNotification = @"com.urbanairship.application_will_resign_active";
NSNotificationName const UAApplicationWillTerminateNotification = @"com.urbanairship.application_will_terminate";
NSNotificationName const UAApplicationDidTransitionToBackground = @"com.urbanairship.application_did_transition_to_background";
NSNotificationName const UAApplicationDidTransitionToForeground = @"com.urbanairship.application_did_transition_to_foreground";

NSString *const UAApplicationLaunchOptionsRemoteNotificationKey = @"com.urbanairship.application_launch_options_remote_notification";

@interface UAAppStateTracker() <UAAppStateTrackerDelegate>
@property (nonatomic, strong) id<UAAppStateTrackerAdapter> adapter;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@property (nonatomic, assign) BOOL isForegrounded;
@end

@implementation UAAppStateTracker

static UAAppStateTracker *shared_;

+ (void)load {
    shared_ = [[UAAppStateTracker alloc] init];
}

+ (instancetype)shared {
    return shared_;
}

- (instancetype)init {
    self = [super init];

    if (self) {
        self.notificationCenter = [NSNotificationCenter defaultCenter];
        self.adapter = [UAUIKitStateTrackerAdapter adapter];
        self.adapter.stateTrackerDelegate = self;
    }

    return self;
}

- (void)applicationDidFinishLaunching:(NSDictionary *)remoteNotification {
    NSDictionary *userInfo = remoteNotification == nil ? nil : @{ UAApplicationLaunchOptionsRemoteNotificationKey : remoteNotification };
    [self.notificationCenter postNotificationName:UAApplicationDidFinishLaunchingNotification
                                           object:nil
                                         userInfo:userInfo];
}

- (void)applicationDidBecomeActive {
    [self.notificationCenter postNotificationName:UAApplicationDidBecomeActiveNotification object:nil];

    if (!self.isForegrounded) {
        self.isForegrounded = YES;
        [self.notificationCenter postNotificationName:UAApplicationDidTransitionToForeground object:nil];
    }
}

- (void)applicationWillEnterForeground {
    [self.notificationCenter postNotificationName:UAApplicationWillEnterForegroundNotification object:nil];
}

- (void)applicationDidEnterBackground {
    [self.notificationCenter postNotificationName:UAApplicationDidEnterBackgroundNotification object:nil];

    if (self.isForegrounded) {
        self.isForegrounded = NO;
        [self.notificationCenter postNotificationName:UAApplicationDidTransitionToBackground object:nil];
    }
}

- (void)applicationWillResignActive {
    [self.notificationCenter postNotificationName:UAApplicationWillResignActiveNotification object:nil];
}

- (void)applicationWillTerminate {
    [self.notificationCenter postNotificationName:UAApplicationWillTerminateNotification object:nil];
}

@end
