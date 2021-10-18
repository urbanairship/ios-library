/* Copyright Airship and Contributors */

#import "UAInAppMessageDefaultDisplayCoordinator+Internal.h"
#import "UAAirshipAutomationCoreImport.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif


@interface UAInAppMessageDefaultDisplayCoordinator ()
@property (nonatomic, assign) BOOL isDisplayLocked;
@property (nonatomic, strong) UADispatcher *dispatcher;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@end

@implementation UAInAppMessageDefaultDisplayCoordinator

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
    if (!self.isDisplayLocked) {
        [self emitChangeNotification:YES];
    }
}

- (void)applicationDidEnterBackground {
    [self emitChangeNotification:NO];
}

- (void)setIsDisplayLocked:(BOOL)isDisplayLocked NS_EXTENSION_UNAVAILABLE("Method not available in app extensions") {
    if (_isDisplayLocked != isDisplayLocked) {
        _isDisplayLocked = isDisplayLocked;

        if (!isDisplayLocked && [[UIApplication sharedApplication] applicationState] == UIApplicationStateActive) {
            [self emitChangeNotification:YES];
        }
    }
}

- (void)emitChangeNotification:(BOOL)ready {
    [self willChangeValueForKey:UAInAppMessageDisplayCoordinatorIsReadyKey];
    [self didChangeValueForKey:UAInAppMessageDisplayCoordinatorIsReadyKey];
}

- (void)didBeginDisplayingMessage:(UAInAppMessage *)message {
    [self lockDisplay];
}

- (void)didFinishDisplayingMessage:(UAInAppMessage *)message {
    [self unlockDisplayAfter:self.displayInterval];
}

- (void)unlockDisplayAfter:(NSTimeInterval)interval {
    UA_WEAKIFY(self)
    [self.dispatcher dispatchAfter:interval block:^{
        UA_STRONGIFY(self)
        self.isDisplayLocked = NO;
    }];
}

- (void)lockDisplay {
    self.isDisplayLocked = YES;
}

- (BOOL)isReady NS_EXTENSION_UNAVAILABLE("Method not available in app extensions") {
    // Require an active application
    if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive) {
        UA_LTRACE(@"Application is not active. Display Coordinator not ready: %@", self);
        return NO;
    }

    // Require a free display lock
    if (self.isDisplayLocked) {
        return NO;
    }

    return YES;
}

@end
