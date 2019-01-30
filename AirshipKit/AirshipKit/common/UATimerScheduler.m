/* Copyright 2010-2019 Urban Airship and Contributors */

#import "UATimerScheduler+Internal.h"

@implementation UATimerScheduler

- (void)scheduleTimer:(NSTimer *)timer {
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
}

@end
