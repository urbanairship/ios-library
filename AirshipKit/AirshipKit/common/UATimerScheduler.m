/* Copyright 2018 Urban Airship and Contributors */

#import "UATimerScheduler+Internal.h"

@implementation UATimerScheduler

- (void)scheduleTimer:(NSTimer *)timer {
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
}

@end
