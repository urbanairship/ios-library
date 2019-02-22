/* Copyright Urban Airship and Contributors */

#import "UATimerScheduler+Internal.h"

@interface UATimerScheduler()
@property (nonatomic, copy) void (^schedulerBlock)(NSTimer *);
@end

@implementation UATimerScheduler

- (instancetype)initWithBlock:(void (^)(NSTimer *))schedulerBlock {
    self = [super init];
    if (self) {
        self.schedulerBlock = schedulerBlock;
    }
    return self;
}

- (void)scheduleTimer:(NSTimer *)timer {
    if (self.schedulerBlock) {
        self.schedulerBlock(timer);
    } else {
        [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    }
}

+ (instancetype)timerScheduler {
    return [[UATimerScheduler alloc] init];
}

+ (instancetype)timerSchedulerWithSchedulerBlock:(void (^)(NSTimer *))schedulerBlock {
    return [[UATimerScheduler alloc] initWithBlock:schedulerBlock];
}

@end
