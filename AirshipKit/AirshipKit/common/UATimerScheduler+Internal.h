/* Copyright 2018 Urban Airship and Contributors */

#import <Foundation/Foundation.h>

@interface UATimerScheduler : NSObject

/*
- (NSTimer *)timerWithTimeInterval:(NSTimeInterval)interval
                            target:(id)target
                          selector:(SEL)selector
                          userInfo:(id)userInfo
                           repeats:(BOOL)yesOrNo;
 */

- (void)scheduleTimer:(NSTimer *)timer;

@end
