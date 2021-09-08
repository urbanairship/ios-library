/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(InAppMessageAssets)
@interface UAInAppMessageAssets : NSObject

/**
 * Return URL at which to cache the assetURL
 *
 * @param assetURL URL from which the cached data is fetched
 * @return URL for the cached asset or `nil` if the asset cannot be cached at this time
 */
- (nullable NSURL *)getCacheURL:(NSURL *)assetURL;

/**
 * Check if data is cached for this asset
 *
 * @param assetURL URL from which the data is fetched
 * @return `YES` if data for the URL is in the cache, `NO` if it is not.
 */
- (BOOL)isCached:(NSURL *)assetURL;

@end

NS_ASSUME_NONNULL_END
