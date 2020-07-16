/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

#import "UAInAppMessageAssetManager.h"
#import "UAInAppMessageAssets.h"
#import "UAInAppMessageAssetCache+Internal.h"

NS_ASSUME_NONNULL_BEGIN

@interface UAInAppMessageAssetManager()

/**
 * Factory method.
 */
+ (instancetype)assetManager;

/**
 * Factory method. Use for testing.
 *
 * @param assetCache Instance of UAInAppMessageAssetCache
 */
+ (instancetype)assetManagerWithAssetCache:(UAInAppMessageAssetCache *)assetCache operationQueue:(NSOperationQueue *)queue;

/**
 * Called when message is being scheduled.
 *
 * If delegate's cache policy supports caching on schedule, fetch and
 * cache all assets for the schedule.
 *
 * @param message The message.
 * @param scheduleID The schedule ID.
 */
- (void)onMessageScheduled:(UAInAppMessage *)message scheduleID:(NSString *)scheduleID;

/**
 * Called when message is being prepared.
 *
 * Fetch and cache any un-cached assets for the schedule.
 *
 * @note All assets must be on-device after this call returns, so the adapter can display the message.
 *
 * @param message The message.
 * @param scheduleID The schedule ID.
 * @param completionHandler The completion handler to call when caching is complete.
 */
- (void)onPrepareMessage:(UAInAppMessage *)message
              scheduleID:(NSString *)scheduleID
       completionHandler:(void (^)(UAInAppMessagePrepareResult))completionHandler;

/**
 * Called when the adapter has finished displaying the message.
 *
 * Unlock the schedule's cache. If delegate's cache policy does not
 * support persisting the cache after display, clear the schedule's cache.
 *
 * @param message The message.
 * @param scheduleID The schedule ID.
 */
- (void)onDisplayFinished:(UAInAppMessage *)message
               scheduleID:(NSString *)scheduleID;

/**
 * Called when the schedule has finished.
 *
 * Clear the cache for the schedule.
 *
 * @note This indicates the message will not be displayed again.
 *
 * @param scheduleID The schedule being finished
 */
- (void)onScheduleFinished:(NSString *)scheduleID;

/**
 * Get the assets for this schedule
 *
 * @param scheduleID The schedule ID.
 * @param completionHandler The completion handler to call with the UAInAppMessageAssets instance for this schedule
 */
- (void)assetsForScheduleID:(NSString *)scheduleID
          completionHandler:(void (^)(UAInAppMessageAssets *))completionHandler;

@end
NS_ASSUME_NONNULL_END
