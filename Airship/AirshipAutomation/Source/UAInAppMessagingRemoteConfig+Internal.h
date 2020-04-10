/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppMessagingTagGroupsConfig+Internal.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Remote config class for in-app messaging.
 */
@interface UAInAppMessagingRemoteConfig : NSObject

/**
 * The inner config for tag group fetching.
 */
@property (nonatomic, readonly) UAInAppMessagingTagGroupsConfig *tagGroupsConfig;

/**
 * UAInAppMessagingRemoteConfig class factory method.
 *
 * @param tagGroupsConfig A UAInAppMessagingTagGroupsConfig.
 */
+ (instancetype)configWithTagGroupsConfig:(UAInAppMessagingTagGroupsConfig *)tagGroupsConfig;

/**
 * Creates a default config.
 * @return The default config.
 */
+ (instancetype)defaultConfig;

/**
 * Parses a config from JSON.
 * @return The UAInAppMessaginTagGroupsConfig instance, or nil if the JSON is invalid.
 */
+ (nullable instancetype)configWithJSON:(id)JSON;

@end

NS_ASSUME_NONNULL_END
