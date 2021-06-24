/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UATask.h"

@class UADispatcher;


NS_ASSUME_NONNULL_BEGIN

/**
 * Task launcher.
 */
@interface UATaskLauncher : NSObject

/**
 * Factory method.
 * @param dispatcher Optional dispatcher. If nil, a global dispatcher will be used.
 * @param launchHandler The launch handler block.
 */
+ (instancetype)launcherWithDispatcher:(nullable UADispatcher *)dispatcher
                         launchHandler:(void (^)(id<UATask>))launchHandler;

/**
 * Launches a task on the dispatcher.
 *
 * @param task The task.
 */
- (void)launch:(id<UATask>)task;

@end

NS_ASSUME_NONNULL_END
