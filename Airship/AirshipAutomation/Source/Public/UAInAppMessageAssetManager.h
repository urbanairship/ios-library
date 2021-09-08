/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

#import "UAInAppMessage.h"
#import "UASchedule.h"
#import "UAInAppMessageAssets.h"
#import "UAInAppMessageAdapterProtocol.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Protocol for customizing in-app message asset cache policy.
 */
NS_SWIFT_NAME(InAppMessageCachePolicyDelegate)
@protocol UAInAppMessageCachePolicyDelegate <NSObject>

/**
 * Return cache policy for caching assets on schedule
 *
 * @param message The message for which the assets will or won't be cached
 * @return `YES` requests the Asset Manager to cache the message's assets when the message is scheduled.
 *
 * @note If unimplemented, the message's assets will not be cached when the message is scheduled.
 */
- (BOOL)shouldCacheOnSchedule:(UAInAppMessage *)message;

/**
 * Return cache policy for retaining cached assets after display
 *
 * @param message The message for which the assets will or won't be cached
 * @return `YES` requests the Asset Manager to persist the caching of the message's assets when
 * the message has finished displaying.
 *
 * @note If unimplemented, the message's assets will not be persisted when the message has finished displaying.
 */
- (BOOL)shouldPersistCacheAfterDisplay:(UAInAppMessage *)message;

@end

/**
 * Protocol for extending in-app message asset fetching.
 */
NS_SWIFT_NAME(InAppMessagePrepareAssetsDelegate)
@protocol UAInAppMessagePrepareAssetsDelegate <NSObject>

/**
 * Extend assets for this message when the message is scheduled
 *
 * @note This method is intended to allow the app to fetch URLs that the SDK may not be able to fetch.
 * It also covers the case where the Asset Manager can't decode the message (Custom message type).
 *
 * @note If implemented, the message WILL NOT display until the completionHandler is called.
 *
 * @param message The message for which the assets can be extended
 * @param assets Assets instance for caching assets
 * @param completionHandler The completion handler to call when asset fetching is complete.
 */
- (void)onSchedule:(UAInAppMessage *)message
            assets:(UAInAppMessageAssets *)assets
 completionHandler:(void (^)(UAInAppMessagePrepareResult))completionHandler;

/**
 * Extend assets for this message when the message is prepared
 *
 * @note This method is intended to allow the app to fetch URLs that the SDK may not be able to fetch.
 * It also covers the case where the Asset Manager can't decode the message (Custom message type).
 *
 * @note If implemented, the message WILL NOT display until the completionHandler is called.
 *
 * @param message The message for which the assets can be extended
 * @param assets Assets instance for caching assets
 * @param completionHandler The completion handler to call when asset fetching is complete.
 */
- (void)onPrepare:(UAInAppMessage *)message
           assets:(UAInAppMessageAssets *)assets
completionHandler:(void (^)(UAInAppMessagePrepareResult))completionHandler;

@end

/**
 * Manages the preparation and caching of in-app message assets.
 */
NS_SWIFT_NAME(InAppMessageAssetManager)
@interface UAInAppMessageAssetManager : NSObject

/**
 * In-app messaging prepare assets delegate.
 */
@property (nonatomic, strong) id<UAInAppMessagePrepareAssetsDelegate> prepareAssetsDelegate;

/**
 * In-app messaging cache policy delegate.
 */
@property (nonatomic, weak) id<UAInAppMessageCachePolicyDelegate> cachePolicyDelegate;

@end

NS_ASSUME_NONNULL_END
