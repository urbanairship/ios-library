/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Remote config class for in-app messaging tag group fetching.
 */
@interface UAInAppMessagingTagGroupsConfig : NSObject

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
 * Factory method to create the default config.
 *
 * @return A UAInAppMessagingTagGroupsConfig instance
 */
+ (instancetype)defaultConfig;

/**
 * UAInAppMessagingTagGroupsConfig class factory method.
 *
 * @param cacheMaxAgeTime The cache max age time.
 * @param cacheStaleReadTime The cache stale read time.
 * @param cachePreferLocalUntil The cache prefer local until time.
 * @param enabled Whether tag group fetching is enabled.
 * @return A UAInAppMessagingTagGroupsConfig instance.
 */
+ (instancetype)configWithCacheMaxAgeTime:(NSTimeInterval)cacheMaxAgeTime
                       cacheStaleReadTime:(NSTimeInterval)cacheStaleReadTime
                    cachePreferLocalUntil:(NSTimeInterval)cachePreferLocalUntil
                                  enabled:(BOOL)enabled;

/**
 * Parses a config from JSON.
 * @return The UAInAppMessagingTagGroupsConfig instance, or nil if the JSON is invalid.
 */
+ (nullable instancetype)configWithJSON:(id)JSON;
@end

NS_ASSUME_NONNULL_END
