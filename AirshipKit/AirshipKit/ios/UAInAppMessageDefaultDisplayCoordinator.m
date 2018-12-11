/* Copyright 2018 Urban Airship and Contributors */

#import "UAInAppMessageDefaultDisplayCoordinator+Internal.h"
#import "UAGlobal.h"

#define kUAInAppMessageDefaultDisplayInterval 30

@interface UAInAppMessageDefaultDisplayCoordinator ()
@property (nonatomic, assign) BOOL isReady;
@property (nonatomic, strong) UADispatcher *dispatcher;
@end

@implementation UAInAppMessageDefaultDisplayCoordinator

- (instancetype)initWithDispatcher:(UADispatcher *)dispatcher {
    self = [super init];

    if (self) {
        self.displayInterval = kUAInAppMessageDefaultDisplayInterval;
        self.dispatcher = dispatcher;
        self.isReady = YES;
    }

    return self;
}

- (instancetype)init {
    self = [super init];

    if (self) {
        self.displayInterval = kUAInAppMessageDefaultDisplayInterval;
        self.dispatcher = [UADispatcher mainDispatcher];
        self.isReady = YES;
    }

    return self;
}

+ (instancetype)coordinator {
    return [[self alloc] init];
}

+ (instancetype)coordinatorWithDispatcher:(UADispatcher *)dispatcher {
    return [[self alloc] initWithDispatcher:dispatcher];
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
        self.isReady = YES;
    }];
}

- (void)lockDisplay {
    self.isReady = NO;
}

- (BOOL)shouldDisplayMessage:(UAInAppMessage *)message {
     // Require an active application
     if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive) {
         UA_LTRACE(@"Application is not active. message: %@ not ready", message.identifier);
         return NO;
     }

    // Require a free display lock
    if (!self.isReady) {
        return NO;
    }

    return YES;
}

@end
