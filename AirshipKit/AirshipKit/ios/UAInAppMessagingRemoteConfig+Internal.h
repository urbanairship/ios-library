/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UARemoteConfig+Internal.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Remote config class for in-app messaging tag group fetching.
 */
@interface UAInAppMessagingTagGroupsRemoteConfig : UARemoteConfig

/**
 * Whether tag group fetching is enabled. Defaults to `YES`.
 */
@property (nonatomic, readonly) BOOL enabled;

/**
 * The cache max age time. Defaults to 10 minutes.
 */
@property (nonatomic, readonly) NSTimeInterval cacheMaxAgeTime;

/**
 * The cache stale read time. Defaults to 1 hour.
 */
@property (nonatomic, readonly) NSTimeInterval cacheStaleReadTime;

/**
 * The time interval to prefer local tag data. Defaults to 10 minutes.
 */
@property (nonatomic, readonly) NSTimeInterval cachePreferLocalUntil;

/**
 * UAInAppMessagingTagGroupsRemoteConfig class factory method.
 *
 * @param cacheMaxAgeTime The cache max age time.
 * @param cacheStaleReadTime The cache stale read time.
 * @param cachePreferLocalUntil The cache prefer local until time.
 * @param enabled Whether tag group fetching is enabled.
 */
+ (instancetype)configWithCacheMaxAgeTime:(NSTimeInterval)cacheMaxAgeTime
                       cacheStaleReadTime:(NSTimeInterval)cacheStaleReadTime
                    cachePreferLocalUntil:(NSTimeInterval)cachePreferLocalUntil
                                  enabled:(BOOL)enabled;

@end

/**
 * Remote config class for in-app messaging.
 */
@interface UAInAppMessagingRemoteConfig : UARemoteConfig

/**
 * The inner config for tag group fetching.
 */
@property (nonatomic, readonly) UAInAppMessagingTagGroupsRemoteConfig *tagGroupsConfig;

/**
 * UAInAppMessagingRemoteConfig class factory method.
 *
 * @param tagGroupsConfig A UAInAppMessagingTagGroupsRemoteConfig.
 */
+ (instancetype)configWithTagGroupsConfig:(UAInAppMessagingTagGroupsRemoteConfig *)tagGroupsConfig;

@end

NS_ASSUME_NONNULL_END
