/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

#import "UAInAppMessageAssets.h"

NS_ASSUME_NONNULL_BEGIN

@interface UAInAppMessageAssetCache : NSObject

/**
 * Factory method
 *
 * @returns instance of this class
 */
+ (UAInAppMessageAssetCache *)assetCache;

/**
 * Return UAInAppMessageAssets instance for schedule id
 *
 * @note if there are already cached assets for this schedule id, use them.
 *
 * @param scheduleId The id of the schedule to cache assets for
 * @return Assets instance to use for caching and accessing assets for this schedule
 */
- (UAInAppMessageAssets *)assetsForScheduleId:(NSString *)scheduleId;

/**
 * Releases assets instance for this schedule id
 *
 * @param scheduleId The id of the schedule for which to release assets instance
 * @param wipeFromDisk Also remove all of the assets from disk
 */
- (void)releaseAssets:(NSString *)scheduleId wipeFromDisk:(BOOL)wipeFromDisk;

/**
 * Clear all cached assets
 */
- (void)clearAllAssets;

@end

NS_ASSUME_NONNULL_END
