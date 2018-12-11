/* Copyright 2018 Urban Airship and Contributors */

#import "UAInAppMessageDefaultDisplayCoordinator+Internal.h"
#import "UAGlobal.h"

#define kUAInAppMessageDefaultDisplayInterval 30

@interface UAInAppMessageDefaultDisplayCoordinator ()
@property (nonatomic, assign) BOOL isDisplayLocked;
@property (nonatomic, strong) UADispatcher *dispatcher;
@property (nonatomic, strong) NSMutableArray<UAInAppMessageDisplayCoordinatorBlock> *blocks;
@end

@implementation UAInAppMessageDefaultDisplayCoordinator

- (instancetype)initWithDispatcher:(UADispatcher *)dispatcher {
    self = [super init];

    if (self) {
        self.displayInterval = kUAInAppMessageDefaultDisplayInterval;
        self.dispatcher = dispatcher;
        self.blocks = [NSMutableArray array];
    }

    return self;
}

- (instancetype)init {
    self = [super init];

    if (self) {
        self.displayInterval = kUAInAppMessageDefaultDisplayInterval;
        self.dispatcher = [UADispatcher mainDispatcher];
        self.blocks = [NSMutableArray array];
    }

    return self;
}

+ (instancetype)coordinator {
    return [[self alloc] init];
}

+ (instancetype)coordinatorWithDispatcher:(UADispatcher *)dispatcher {
    return [[self alloc] initWithDispatcher:dispatcher];
}

- (UAInAppMessageDisplayCoordinatorBlock)didBeginDisplayingMessage:(UAInAppMessage *)message {
    [self lockDisplay];

    return ^{
        [self unlockDisplayAfter:self.displayInterval];
    };
}

- (void)whenNextAvailable:(UAInAppMessageDisplayCoordinatorBlock)block {
    if (block) {
        [self.blocks addObject:block];

        if (!self.isDisplayLocked) {
            [self notifyAvailability];
        }
    }
}

- (void)notifyAvailability {
    UAInAppMessageDisplayCoordinatorBlock block = [self.blocks firstObject];

    if (block) {
        [self.blocks removeObjectAtIndex:0];

        block();
    }
}

- (void)unlockDisplayAfter:(NSTimeInterval)interval {
    UA_WEAKIFY(self)
    [self.dispatcher dispatchAfter:interval block:^{
        UA_STRONGIFY(self)
        self.isDisplayLocked = NO;
        [self notifyAvailability];
    }];
}

- (void)lockDisplay {
    self.isDisplayLocked = YES;
}

- (BOOL)shouldDisplayMessage:(UAInAppMessage *)message {
     // Require an active application
     if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive) {
         UA_LTRACE(@"Application is not active. message: %@ not ready", message.identifier);
         return NO;
     }

    // Require a free display lock
    if (self.isDisplayLocked) {
        return NO;
    }

    return YES;
}

@end
