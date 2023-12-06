/* Copyright Airship and Contributors */

#import "UAInAppMessageImmediateDisplayCoordinator.h"
#import "UAAirshipAutomationCoreImport.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif


@interface UAInAppMessageImmediateDisplayCoordinator ()
@property (nonatomic, strong) UADispatcher *dispatcher;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@end

@implementation UAInAppMessageImmediateDisplayCoordinator

- (instancetype)initWithDispatcher:(UADispatcher *)dispatcher notificationCenter:(NSNotificationCenter *)notificationCenter {
    self = [super init];

    if (self) {
        self.dispatcher = dispatcher;
        self.notificationCenter = notificationCenter;

        [self.notificationCenter addObserver:self selector:@selector(applicationDidBecomeActive) name:UAAppStateTracker.didBecomeActiveNotification object:nil];
        [self.notificationCenter addObserver:self selector:@selector(applicationDidEnterBackground) name:UAAppStateTracker.didEnterBackgroundNotification object:nil];
    }

    return self;
}

- (instancetype)init {
    return [self initWithDispatcher:UADispatcher.main
                 notificationCenter:[NSNotificationCenter defaultCenter]];
}

+ (instancetype)coordinator {
    return [[self alloc] init];
}

+ (instancetype)coordinatorWithDispatcher:(UADispatcher *)dispatcher notificationCenter:(NSNotificationCenter *)notificationCenter {
    return [[self alloc] initWithDispatcher:dispatcher notificationCenter:notificationCenter];
}

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key {
    if ([key isEqualToString:UAInAppMessageDisplayCoordinatorIsReadyKey]) {
        return NO;
    }
    return [super automaticallyNotifiesObserversForKey:key];
}

- (void)applicationDidBecomeActive {
    [self emitChangeNotification:YES];
}

- (void)applicationDidEnterBackground {
    [self emitChangeNotification:NO];
}

- (void)emitChangeNotification:(BOOL)ready {
    [self willChangeValueForKey:UAInAppMessageDisplayCoordinatorIsReadyKey];
    [self didChangeValueForKey:UAInAppMessageDisplayCoordinatorIsReadyKey];
}

- (BOOL)isReady NS_EXTENSION_UNAVAILABLE("Method not available in app extensions") {
    // Require an active application
    if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive) {
        UA_LTRACE(@"Application is not active. Display Coordinator not ready: %@", self);
        return NO;
    }

    return YES;
}

@end
