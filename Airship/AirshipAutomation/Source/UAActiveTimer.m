/* Copyright Airship and Contributors */

#import "UAActiveTimer+Internal.h"
#import "UAAppStateTracker.h"

@interface UAActiveTimer()
@property (assign, getter=isStarted) BOOL started;
@property (assign, getter=isActive) BOOL active;
@property (assign) NSTimeInterval elapsedTime;
@property (strong) NSDate *activeStartDate;
@end

@implementation UAActiveTimer

- (instancetype)init {
    self = [super init];
    if (self) {
        self.active = [UAAppStateTracker shared].state == UAApplicationStateActive;

        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

        [notificationCenter addObserver:self
                               selector:@selector(applicationDidBecomeActive)
                                   name:UAApplicationDidBecomeActiveNotification
                                 object:nil];

        [notificationCenter addObserver:self
                               selector:@selector(applicationWillResignActive)
                                   name:UAApplicationWillResignActiveNotification
                                 object:nil];

    }

    return self;
}

- (void)start {
    if (self.isStarted) {
        return;
    }

    if (self.active) {
        self.activeStartDate = [NSDate date];
    }

    self.started = YES;
}

- (void)stop {
    if (!self.started) {
        return;
    }

    if (self.activeStartDate) {
        self.elapsedTime += [[NSDate date] timeIntervalSinceDate:self.activeStartDate];
        self.activeStartDate = nil;
    }

    self.started = NO;
}

- (void)applicationDidBecomeActive {
    self.active = YES;
    if (self.started) {
        self.activeStartDate = [NSDate date];
    }
}

- (void)applicationWillResignActive {
    self.active = NO;
    if (self.started && self.activeStartDate) {
        self.elapsedTime += [[NSDate date] timeIntervalSinceDate:self.activeStartDate];
        self.activeStartDate = nil;
    }
}

- (NSTimeInterval)time {
    NSTimeInterval totalTime = self.elapsedTime;
    if (self.started && self.activeStartDate) {
        totalTime += [[NSDate date] timeIntervalSinceDate:self.activeStartDate];
    }
    return totalTime;
}

@end

