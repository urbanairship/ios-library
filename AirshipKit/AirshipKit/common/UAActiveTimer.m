/* Copyright Urban Airship and Contributors */


#import "UAActiveTimer+Internal.h"
#import <UIKit/UIKit.h>

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
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didBecomeActive)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(willResignActive)
                                                     name:UIApplicationWillResignActiveNotification
                                                   object:nil];

        self.active = ([UIApplication sharedApplication].applicationState == UIApplicationStateActive);
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

- (void)didBecomeActive {
    self.active = YES;
    if (self.started) {
        self.activeStartDate = [NSDate date];
    }
}

- (void)willResignActive {
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

