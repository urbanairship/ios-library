/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UATask.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * A UATask instance.
 */
@interface UAExpirableTask : NSObject <UATask>

/**
 * Factory method.
 * @param taskID The task ID.
 * @param completionHandler Called when the task is finished.
 */
+ (instancetype)taskWithID:(NSString *)taskID
                   options:(UATaskRequestOptions *)requestOptions
         completionHandler:(void (^)(BOOL))completionHandler;

/**
 * Expires the task.
 */
- (void)expire;

@end

NS_ASSUME_NONNULL_END
