/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UATask.h"
#import "UATaskRequestOptions.h"

@class UADispatcher;

NS_ASSUME_NONNULL_BEGIN

/**
 * Manages tasks for Airship.
 * @note For internal use only. :nodoc:
 */
@interface UATaskManager : NSObject

/**
 * Gets the shared task manager instance.
 *
 * @return The shared task manager instance.
 */
+ (instancetype)shared;

/**
 * Registers a task launcher for the array of identifiers.
 * @param identifiers The task identifiers.
 * @param dispatcher The dispatcher
 * @param launchHandler The launch handler.
 */
- (void)registerForTaskWithIDs:(NSArray<NSString *> *)identifiers
                   dispatcher:(nullable UADispatcher *)dispatcher
                launchHandler:(void (^)(id<UATask>))launchHandler;

/**
 * Registers a task launcher for the given identifier.
 * @param identifier The task identifier.
 * @param dispatcher The dispatcher
 * @param launchHandler The launch handler.
 */
- (void)registerForTaskWithID:(NSString *)identifier
                   dispatcher:(nullable UADispatcher *)dispatcher
                launchHandler:(void (^)(id<UATask>))launchHandler;

/**
 * Enqueues a task request.
 * @note Only registered launchers at the time of enqueueing will be used to process the request.
 * @param taskID The task ID.
 * @param options The request options.
 */
- (void)enqueueRequestWithID:(NSString *)taskID
                     options:(UATaskRequestOptions *)options;

/**
 * Enqueues a task request.
 * @note Only registered launchers at the time of enqueueing will be used to process the request.
 * @param taskID The task ID.
 * @param options The request options.
 * @param initialDelay The initial delay.
 */
- (void)enqueueRequestWithID:(NSString *)taskID
                     options:(UATaskRequestOptions *)options
                initialDelay:(NSTimeInterval)initialDelay;

@end

NS_ASSUME_NONNULL_END
