/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UATaskRequestOptions.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Task passed to the launcher when ready to execute.
 * @note For internal use only. :nodoc:
 */
@protocol UATask <NSObject>

/**
 * Expiration handler. Will be called when background time is about to expire. The launcher is still expected to call `taskCompleted` or `taskFailed`.
 */
@property(nonatomic, copy, nullable) void (^expirationHandler)(void);

/**
 * The task ID.
 */
@property(nonatomic, readonly) NSString *taskID;

/**
 * The task request options.
 */
@property(nonatomic, readonly) UATaskRequestOptions *requestOptions;

/**
 * The launcher should call this method to signal that the task was completed succesfully.
 */
- (void)taskCompleted;

/**
 * The launcher should call this method to signal the task failed and needs to be retried.
 */
- (void)taskFailed;

@end

NS_ASSUME_NONNULL_END
