/* Copyright Urban Airship and Contributors */

#import "UAInAppMessageDefaultDisplayCoordinator+Internal.h"
#import "UAGlobal.h"

#define kUAInAppMessageDefaultDisplayInterval 30

@interface UAInAppMessageDefaultDisplayCoordinator ()
@property (nonatomic, assign) BOOL isDisplayLocked;
@property (nonatomic, strong) UADispatcher *dispatcher;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@end

@implementation UAInAppMessageDefaultDisplayCoordinator

- (instancetype)initWithDispatcher:(UADispatcher *)dispatcher notificationCenter:(NSNotificationCenter *)notificationCenter {
    self = [super init];

    if (self) {
        self.displayInterval = kUAInAppMessageDefaultDisplayInterval;
        self.dispatcher = dispatcher;
        self.notificationCenter = notificationCenter;

        [self.notificationCenter addObserver:self selector:@selector(didBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
        [self.notificationCenter addObserver:self selector:@selector(didEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
    }

    return self;
}

- (instancetype)init {
    return [self initWithDispatcher:[UADispatcher mainDispatcher]
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

- (void)didBecomeActive {
    if (!self.isDisplayLocked) {
        [self emitChangeNotification:YES];
    }
}

- (void)didEnterBackground {
    [self emitChangeNotification:NO];
}

- (void)setIsDisplayLocked:(BOOL)isDisplayLocked {
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

- (BOOL)isReady {
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
